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
    render json: { id: ds.id, name: ds.name }, status: :created
  end

  private

  def ds_params
    # Accept both wrapped and unwrapped params
    if params[:design_system].present?
      params.require(:design_system).permit(:name, component_library_ids: [])
    else
      params.permit(:name, component_library_ids: [])
    end
  end
end
