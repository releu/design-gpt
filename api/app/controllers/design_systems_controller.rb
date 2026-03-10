class DesignSystemsController < ApplicationController
  include Renderable

  before_action :require_auth, except: [:renderer]

  def renderer
    ds = DesignSystem.find(params[:id])
    html = render_component_libraries(ds.figma_files)
    render html: html.html_safe, layout: false
  end

  def index
    design_systems = current_user.design_systems.includes(:figma_files).order(created_at: :desc)
    render json: design_systems.map { |ds|
      {
        id: ds.id,
        name: ds.name,
        figma_file_ids: ds.figma_file_ids,
        libraries: ds.figma_files.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } },
        created_at: ds.created_at
      }
    }
  end

  def create
    dp = ds_params
    ds = current_user.design_systems.create!(
      name: dp[:name]
    )
    Array(dp[:figma_file_ids]).each do |ff_id|
      ds.design_system_libraries.create!(figma_file_id: ff_id)
    end
    render json: {
      id: ds.id,
      name: ds.name,
      figma_file_ids: ds.figma_file_ids,
      libraries: ds.figma_files.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } }
    }, status: :created
  end

  def show
    ds = find_user_design_system(params[:id])
    render json: {
      id: ds.id,
      name: ds.name,
      figma_file_ids: ds.figma_file_ids,
      libraries: ds.figma_files.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } },
      created_at: ds.created_at
    }
  end

  def update
    ds = find_user_design_system(params[:id])
    ds.update!(ds_params.except(:figma_file_ids))

    if params[:figma_file_ids].present? || params.dig(:design_system, :figma_file_ids).present? ||
       params[:component_library_ids].present? || params.dig(:design_system, :component_library_ids).present?
      new_ids = Array(ds_params[:figma_file_ids] || ds_params[:component_library_ids]).map(&:to_i)
      ds.design_system_libraries.where.not(figma_file_id: new_ids).destroy_all
      new_ids.each do |ff_id|
        ds.design_system_libraries.find_or_create_by!(figma_file_id: ff_id)
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
      params.require(:design_system).permit(:name, figma_file_ids: [], component_library_ids: [])
    else
      params.permit(:name, figma_file_ids: [], component_library_ids: [])
    end
  end
end
