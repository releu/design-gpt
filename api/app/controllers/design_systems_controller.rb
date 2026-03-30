class DesignSystemsController < ApplicationController
  include Renderable

  before_action :require_auth, except: [:renderer, :show]

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

    # Link existing figma files by ID
    Array(dp[:figma_file_ids]).each do |ff_id|
      ff = current_user.figma_files.find(ff_id)
      ff.update!(design_system: ds, version: ds.version)
    end

    # Create and link figma files from URLs
    Array(dp[:figma_urls]).each do |url|
      next if url.blank?
      ff = current_user.figma_files.find_by(figma_url: url) ||
           current_user.figma_files.create!(figma_url: url)
      ff.update!(design_system: ds, version: ds.version)
    end

    # Auto-sync if there are files to sync
    ds.sync_async if ds.current_figma_files.any?

    ds.reload
    libs = ds.current_figma_files
    render json: {
      id: ds.id,
      name: ds.name,
      status: ds.status,
      version: ds.version,
      progress: ds.progress,
      figma_file_ids: libs.pluck(:id),
      figma_files: libs.map { |ff| { id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url } }
    }, status: :created
  end

  def show
    ds = find_viewable_design_system(params[:id])
    # When syncing, show in-progress files (next version) so frontend gets live progress
    libs = if %w[pending importing converting].include?(ds.status)
      ds.figma_files.where(version: ds.version + 1).presence || ds.current_figma_files
    else
      ds.current_figma_files
    end
    is_owner = current_user&.id == ds.user_id
    render json: {
      id: ds.id,
      name: ds.name,
      version: ds.version,
      status: ds.status,
      progress: ds.progress,
      is_owner: is_owner,
      figma_working_file_key: ds.figma_working_file_key,
      figma_file_ids: libs.pluck(:id),
      figma_files: libs.map { |ff| {
        id: ff.id, name: ff.name || ff.figma_file_name, figma_url: ff.figma_url,
        status: ff.status, progress: ff.progress
      } },
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

  def find_viewable_design_system(id)
    if current_user
      ds = current_user.design_systems.find_by(id: id)
      return ds if ds
    end
    DesignSystem.find(id)
  end

  def find_syncable_design_system(id)
    current_user.design_systems.find_by(id: id) ||
      DesignSystem.where(is_public: true).find(id)
  end

  def ds_params
    if params[:design_system].present?
      params.require(:design_system).permit(:name, :is_public, :figma_working_file_key, figma_file_ids: [], figma_urls: [])
    else
      params.permit(:name, :is_public, :figma_working_file_key, figma_file_ids: [], figma_urls: [])
    end
  end
end
