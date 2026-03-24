class IterationsController < ApplicationController
  include Renderable

  skip_before_action :require_auth, raise: false

  def renderer
    iteration = Iteration.find(params[:id])
    libraries = iteration.design.figma_files
    used = extract_component_names(iteration.jsx) if iteration.jsx.present?
    usages = extract_component_usages(iteration.jsx) if iteration.jsx.present?
    precompiled = precompile_jsx(iteration.jsx) if iteration.jsx.present?
    html = render_figma_files(libraries, only: used, precompiled_jsx: precompiled, component_usages: usages)
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

  def export_react
    iteration = Iteration.find_by!(share_code: params[:share_code])
    design = iteration.design
    jsx = iteration.jsx

    if jsx.blank?
      head :not_found
      return
    end

    zip_data = Exports::ReactProjectBuilder.new(design).build
    send_data zip_data, type: "application/zip", disposition: "attachment",
      filename: "#{design.name.parameterize}-react.zip"
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
