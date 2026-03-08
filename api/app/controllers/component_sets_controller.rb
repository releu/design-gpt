class ComponentSetsController < ApplicationController
  before_action :require_auth

  # POST /api/component-sets/:id/reimport
  # Re-imports a single component set from Figma
  def reimport
    component_set = ComponentSet.find(params[:id])
    importer = Figma::SingleComponentImporter.new(component_set.component_library)
    importer.reimport_component_set(component_set)
    render json: {
      id: component_set.id,
      name: component_set.name,
      variants_count: component_set.variants.count
    }
  end

  def update
    component_set = ComponentSet.find(params[:id])
    component_set.update!(component_set_params)
    render json: {
      id: component_set.id,
      name: component_set.name,
      is_root: component_set.is_root,
      slots: component_set.slots
    }
  end

  private

  def component_set_params
    params.require(:component_set).permit(:name)
  end
end
