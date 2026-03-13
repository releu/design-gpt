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

  def shared
    iteration = Iteration.find_by!(share_code: params[:share_code])
    design = iteration.design

    render json: {
      id: design.id,
      name: design.name,
      share_code: iteration.share_code,
      iteration_id: iteration.id,
      jsx: iteration.jsx
    }
  end

  def export_figma
    iteration = Iteration.find_by!(share_code: params[:share_code])

    if iteration.tree.blank?
      head :not_found
      return
    end

    design = iteration.design
    tree = iteration.tree
    if design.design_system
      builder = Exports::FigmaTreeBuilder.new(design)
      tree = builder.build(tree)
    end

    render json: {
      design_id: design.id,
      name: design.name,
      tree: tree,
      jsx: iteration.jsx
    }
  end
end
