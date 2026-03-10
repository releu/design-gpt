class IterationsController < ApplicationController
  include Renderable

  skip_before_action :require_auth, raise: false

  def renderer
    iteration = Iteration.find(params[:id])
    if iteration.figma_file_ids.present?
      libraries = FigmaFile.where(id: iteration.figma_file_ids)
    else
      libraries = iteration.design.figma_files
    end
    html = render_component_libraries(libraries)
    render html: html.html_safe, layout: false
  end
end
