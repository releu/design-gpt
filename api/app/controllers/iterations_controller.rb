class IterationsController < ApplicationController
  include Renderable

  skip_before_action :require_auth, raise: false

  def renderer
    iteration = Iteration.find(params[:id])
    if iteration.component_library_ids.present?
      libraries = ComponentLibrary.where(id: iteration.component_library_ids)
    else
      libraries = iteration.design.component_libraries
    end
    html = render_component_libraries(libraries)
    render html: html.html_safe, layout: false
  end
end
