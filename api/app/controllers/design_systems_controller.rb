class DesignSystemsController < ApplicationController
  include Renderable

  before_action :require_auth, except: [:renderer]

  def renderer
    ds = DesignSystem.find(params[:id])
    html = render_figma_files(ds.current_figma_files)
    render html: html.html_safe, layout: false
  end

  def index
    own = current_user.design_systems.order(created_at: :desc)
    public_ds = DesignSystem.where(is_public: true).where.not(user_id: current_user.id).order(created_at: :desc)
    design_systems = own + public_ds
    render json: design_systems.map { |ds|
      libs = ds.current_figma_files
      {
        id: ds.id,
        name: ds.name,
        is_public: ds.is_public,
        owner_name: ds.user&.email&.split("@")&.first || ds.user&.username,
        version: ds.version,
        status: ds.status,
        figma_file_ids: libs.pluck(:id),
        figma_files: libs.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } },
        created_at: ds.created_at
      }
    }
  end

  def create
    dp = ds_params
    ds = current_user.design_systems.create!(
      name: dp[:name],
      version: 1,
      status: "ready"
    )
    Array(dp[:figma_file_ids]).each do |ff_id|
      ff = current_user.figma_files.find(ff_id)
      ff.update!(design_system: ds, version: ds.version)
    end
    libs = ds.current_figma_files
    render json: {
      id: ds.id,
      name: ds.name,
      figma_file_ids: libs.pluck(:id),
      figma_files: libs.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } }
    }, status: :created
  end

  def show
    ds = find_user_design_system(params[:id])
    libs = ds.current_figma_files
    render json: {
      id: ds.id,
      name: ds.name,
      version: ds.version,
      status: ds.status,
      progress: ds.progress,
      figma_file_ids: libs.pluck(:id),
      figma_files: libs.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } },
      created_at: ds.created_at
    }
  end

  def update
    ds = find_user_design_system(params[:id])
    ds.update!(ds_params.except(:figma_file_ids))
    render json: { id: ds.id, name: ds.name }
  end

  def sync
    ds = find_syncable_design_system(params[:id])
    new_version = ds.sync_async
    if new_version
      render json: { id: ds.id, status: ds.reload.status, version: new_version, progress: ds.progress }
    else
      render json: { id: ds.id, status: ds.reload.status, version: ds.version, progress: ds.progress }
    end
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

  def find_syncable_design_system(id)
    current_user.design_systems.find_by(id: id) ||
      DesignSystem.where(is_public: true).find(id)
  end

  def ds_params
    if params[:design_system].present?
      params.require(:design_system).permit(:name, :is_public, figma_file_ids: [])
    else
      params.permit(:name, :is_public, figma_file_ids: [])
    end
  end
end
