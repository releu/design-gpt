class FigmaRenderJob < ApplicationJob
  queue_as :default

  def perform(design_id, file_key)
    design = Design.find(design_id)
    design.update!(figma_render_status: "rendering")

    renderer = Figma::CanvasRenderer.new
    result = renderer.render(design, file_key: file_key)

    design.update!(
      figma_render_status: "done",
      figma_render_result: result
    )
  rescue => e
    design&.update(
      figma_render_status: "error",
      figma_render_result: { "error" => e.message }
    )
    raise
  end
end
