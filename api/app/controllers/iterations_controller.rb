class IterationsController < ApplicationController
  include Renderable

  skip_before_action :require_auth, raise: false

  def renderer
    iteration = Iteration.find(params[:id])
    if iteration.design_system_id && iteration.design_system_version
      libraries = FigmaFile.where(design_system_id: iteration.design_system_id, version: iteration.design_system_version)
    else
      libraries = iteration.design.figma_files
    end
    html = render_figma_files(libraries)
    render html: html.html_safe, layout: false
  end
end
