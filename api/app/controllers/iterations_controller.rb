class IterationsController < ApplicationController
  include Renderable

  skip_before_action :require_auth, raise: false

  def renderer
    iteration = Iteration.find(params[:id])
    libraries = iteration.design.component_libraries
    html = render_component_libraries(libraries)
    render html: html.html_safe, layout: false
  end
end
