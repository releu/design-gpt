class FigmaFileSyncJob < ApplicationJob
  queue_as :default

  def perform(figma_file_id, old_version_id = nil)
    figma_file = FigmaFile.find(figma_file_id)
    figma_file.sync_with_figma

    # After successful sync, swap design_system_libraries to point to the new version
    if old_version_id.present? && figma_file.status == "ready"
      DesignSystemLibrary.where(figma_file_id: old_version_id)
                         .update_all(figma_file_id: figma_file_id)
    end
  end
end
