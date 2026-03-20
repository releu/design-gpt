class DesignSystemFigmaFilesController < ApplicationController
  before_action :require_auth

  # POST /api/design-systems/:design_system_id/figma-files
  def create
    ds = current_user.design_systems.find(params[:design_system_id])
    ff_id = params[:figma_file_id] || params[:component_library_id]
    ff = current_user.figma_files.find(ff_id)
    ff.update!(design_system: ds)
    render json: { design_system_id: ds.id, figma_file_id: ff.id }, status: :created
  end

  # DELETE /api/design-systems/:design_system_id/figma-files/:id
  def destroy
    ds = current_user.design_systems.find(params[:design_system_id])
    ff = ds.figma_files.find(params[:id])
    # Unlink all versions of this file so it doesn't resurface on next sync
    ds.figma_files.where(figma_file_key: ff.figma_file_key).update_all(design_system_id: nil)
    head :no_content
  end
end
