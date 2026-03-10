class VisualDiffJob < ApplicationJob
  queue_as :default

  def perform(figma_file_id)
    figma_file = FigmaFile.find(figma_file_id)
    figma_file.run_visual_diff
  end
end
