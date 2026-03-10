class ComponentLibrarySyncJob < ApplicationJob
  queue_as :default

  def perform(component_library_id, old_version_id = nil)
    component_library = ComponentLibrary.find(component_library_id)
    component_library.sync_with_figma

    # After successful sync, swap design_system_libraries to point to the new version
    if old_version_id.present? && component_library.status == "ready"
      DesignSystemLibrary.where(component_library_id: old_version_id)
                         .update_all(component_library_id: component_library_id)
    end
  end
end
