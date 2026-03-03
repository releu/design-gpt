class VisualDiffJob < ApplicationJob
  queue_as :default

  def perform(component_library_id)
    library = ComponentLibrary.find(component_library_id)
    library.run_visual_diff
  end
end
