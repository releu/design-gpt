class CustomComponentsController < ApplicationController
  before_action :require_auth

  # POST /api/custom-components
  # Params: { name, description, react_code, prop_types, component_library_id, is_root, allowed_children }
  # Also accepts wrapped: { custom_component: { ... } }
  def create
    cp = component_params
    library = current_user.component_libraries.find(cp[:component_library_id])

    component = library.components.create!(
      name: cp[:name],
      description: cp[:description],
      react_code: cp[:react_code],
      prop_types: cp[:prop_types] || {},
      source: "upload",
      node_id: "upload-#{SecureRandom.hex(8)}",
      status: "imported",
      enabled: true,
      is_root: cp[:is_root] || false,
      allowed_children: cp[:allowed_children] || []
    )

    # Compile JSX to vanilla JS for the renderer
    compiled = compile_jsx(component.react_code, component.name)
    component.update!(react_code_compiled: compiled) if compiled

    # Build prop_definitions from prop_types for DesignGenerator compatibility
    component.update!(prop_definitions: build_prop_definitions(component.prop_types))

    render json: {
      id: component.id,
      name: component.name,
      description: component.description,
      source: component.source,
      status: component.status
    }, status: :created
  end

  # PATCH /api/custom-components/:id
  def update
    component = find_user_component(params[:id])
    up = component_update_params
    component.update!(up)

    if up[:react_code].present?
      compiled = compile_jsx(component.react_code, component.name)
      component.update!(react_code_compiled: compiled) if compiled
    end

    if up[:prop_types].present?
      component.update!(prop_definitions: build_prop_definitions(component.prop_types))
    end

    render json: { id: component.id, name: component.name }
  end

  # DELETE /api/custom-components/:id
  def destroy
    component = find_user_component(params[:id])
    component.destroy!
    head :no_content
  end

  private

  def component_params
    # Accept both wrapped and unwrapped params
    if params[:custom_component].present?
      params.require(:custom_component).permit(:name, :description, :react_code,
        :component_library_id, :is_root, allowed_children: [],
        prop_types: {})
    elsif params[:component].present?
      params.require(:component).permit(:name, :description, :react_code,
        :component_library_id, :is_root, allowed_children: [],
        prop_types: {})
    else
      params.permit(:name, :description, :react_code,
        :component_library_id, :is_root, allowed_children: [],
        prop_types: {})
    end
  end

  def component_update_params
    if params[:custom_component].present?
      params.require(:custom_component).permit(:name, :description, :react_code,
        :is_root, allowed_children: [], prop_types: {})
    elsif params[:component].present?
      params.require(:component).permit(:name, :description, :react_code,
        :is_root, allowed_children: [], prop_types: {})
    else
      params.permit(:name, :description, :react_code,
        :is_root, allowed_children: [], prop_types: {})
    end
  end

  def find_user_component(id)
    Component.where(source: "upload")
      .joins(:component_library)
      .where(component_libraries: { user_id: current_user.id })
      .find(id)
  end

  def compile_jsx(react_code, name)
    "window.#{name} = (function() { #{react_code} return #{name}; })();"
  end

  def build_prop_definitions(prop_types)
    return {} unless prop_types.is_a?(Hash)

    prop_types.each_with_object({}) do |(name, type_str), result|
      type_str = type_str.to_s
      if type_str.start_with?("enum:")
        values = type_str.sub("enum:", "").split(",").map(&:strip)
        result[name] = { "type" => "VARIANT", "defaultValue" => values.first }
      elsif type_str == "boolean"
        result[name] = { "type" => "BOOLEAN" }
      else
        result[name] = { "type" => "TEXT" }
      end
    end
  end
end
