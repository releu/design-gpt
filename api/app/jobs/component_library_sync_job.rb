class ComponentLibrarySyncJob < ApplicationJob
  queue_as :default

  def perform(component_library_id)
    component_library = ComponentLibrary.find(component_library_id)
    component_library.sync_with_figma
  end
end
