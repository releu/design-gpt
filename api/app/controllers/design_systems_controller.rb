class DesignSystemsController < ApplicationController
  include Renderable

  before_action :require_auth, except: [:renderer]

  def renderer
    ds = DesignSystem.find(params[:id])
    html = render_component_libraries(ds.component_libraries)
    render html: html.html_safe, layout: false
  end

  def index
    design_systems = current_user.design_systems.includes(:component_libraries).order(created_at: :desc)
    render json: design_systems.map { |ds|
      {
        id: ds.id,
        name: ds.name,
        component_library_ids: ds.component_library_ids,
        libraries: ds.component_libraries.map { |lib| { id: lib.id, name: lib.name || lib.figma_file_name } },
        created_at: ds.created_at
      }
    }
  end

  def create
    dp = ds_params
    ds = current_user.design_systems.create!(
      name: dp[:name]
    )
    Array(dp[:component_library_ids]).each do |lib_id|
      ds.design_system_libraries.create!(component_library_id: lib_id)
    end
    render json: {
      id: ds.id,
      name: ds.name,
      component_library_ids: ds.component_library_ids,
      libraries: ds.component_libraries.map { |lib| { id: lib.id, name: lib.name || lib.figma_file_name } }
    }, status: :created
  end

  def show
    ds = find_user_design_system(params[:id])
    render json: {
      id: ds.id,
      name: ds.name,
      component_library_ids: ds.component_library_ids,
      libraries: ds.component_libraries.map { |lib| { id: lib.id, name: lib.name || lib.figma_file_name } },
      created_at: ds.created_at
    }
  end

  def update
    ds = find_user_design_system(params[:id])
    ds.update!(ds_params.except(:component_library_ids))

    if params[:component_library_ids].present? || params.dig(:design_system, :component_library_ids).present?
      new_ids = Array(ds_params[:component_library_ids]).map(&:to_i)
      ds.design_system_libraries.where.not(component_library_id: new_ids).destroy_all
      new_ids.each do |lib_id|
        ds.design_system_libraries.find_or_create_by!(component_library_id: lib_id)
      end
    end

    render json: { id: ds.id, name: ds.name }
  end

  def destroy
    ds = find_user_design_system(params[:id])
    ds.destroy!
    head :no_content
  end

  private

  def find_user_design_system(id)
    current_user.design_systems.find(id)
  end

  def ds_params
    # Accept both wrapped and unwrapped params
    if params[:design_system].present?
      params.require(:design_system).permit(:name, component_library_ids: [])
    else
      params.permit(:name, component_library_ids: [])
    end
  end
end
