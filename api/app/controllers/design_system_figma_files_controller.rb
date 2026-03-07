class DesignSystemFigmaFilesController < ApplicationController
  before_action :require_auth

  # POST /api/design-systems/:design_system_id/figma-files
  def create
    ds = current_user.design_systems.find(params[:design_system_id])
    lib_id = params[:component_library_id] || params[:figma_file_id]
    ds.design_system_libraries.create!(component_library_id: lib_id)
    render json: { design_system_id: ds.id, component_library_id: lib_id.to_i }, status: :created
  end

  # DELETE /api/design-systems/:design_system_id/figma-files/:id
  def destroy
    ds = current_user.design_systems.find(params[:design_system_id])
    link = ds.design_system_libraries.find_by!(component_library_id: params[:id])
    link.destroy!
    head :no_content
  end
end
