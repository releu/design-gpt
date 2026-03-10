class ComponentsController < ApplicationController
  skip_before_action :require_auth, only: [:figma_json, :svg, :html_preview, :component_set_figma_json, :component_set_svg, :visual_diff, :diff_image, :screenshot], raise: false

  def svg
    component = Component.find(params[:id])
    node_id = params[:node_id] || component.node_id

    # Use cached SVG if available
    asset = component.figma_assets.svgs.find_by(node_id: node_id)
    if asset&.content.present?
      render plain: asset.content, content_type: "image/svg+xml"
      return
    end

    # Fetch from Figma and cache
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    response = figma.export_svg(component.figma_file_key, node_id)
    svg_url = response.dig("images", node_id)

    if svg_url.blank?
      render plain: "<!-- SVG not available -->", content_type: "image/svg+xml"
      return
    end

    svg_content = figma.fetch_svg_content(svg_url)

    # Cache for next time
    component.figma_assets.find_or_initialize_by(node_id: node_id).update!(
      name: component.name,
      asset_type: "svg",
      content: svg_content
    )

    render plain: svg_content, content_type: "image/svg+xml"
  end

  # GET /api/components/:id/html_preview
  # Renders the component's HTML/CSS as a standalone preview page
  def html_preview
    component = Component.find(params[:id])

    if component.html_code.blank?
      render plain: "No HTML available for this component", status: :not_found
      return
    end

    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{ERB::Util.html_escape(component.name)} - Preview</title>
        <style>
          body {
            margin: 0;
            padding: 24px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            display: flex;
            justify-content: center;
            align-items: flex-start;
          }
          .preview-container {
            background: white;
            border-radius: 8px;
            padding: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          }
          #{component.css_code}
        </style>
      </head>
      <body>
        <div class="preview-container">
          #{component.html_code}
        </div>
      </body>
      </html>
    HTML

    render html: html.html_safe, layout: false
  end

  # POST /api/components/:id/reimport
  # Re-imports a single component from Figma
  def reimport
    component = Component.find(params[:id])
    importer = Figma::SingleComponentImporter.new(component.figma_file)
    importer.reimport_component(component)
    render json: {
      id: component.id,
      name: component.name,
      status: component.reload.status
    }
  end

  # GET /api/components/:id/visual_diff
  # Returns visual diff results (match_percent, image paths)
  def visual_diff
    component = Component.find(params[:id])
    render json: {
      id: component.id,
      name: component.name,
      match_percent: component.match_percent,
      has_diff: component.diff_image_path.present?,
      has_figma_screenshot: component.figma_screenshot_path.present?,
      has_react_screenshot: component.react_screenshot_path.present?
    }
  end

  # GET /api/components/:id/diff_image
  # Serves the diff image PNG
  def diff_image
    component = Component.find(params[:id])
    serve_image(component.diff_image_path, "diff image")
  end

  # GET /api/components/:id/screenshots/:type
  # Serves figma or react screenshot (type = "figma" or "react")
  def screenshot
    component = Component.find(params[:id])
    case params[:type]
    when "figma"
      serve_image(component.figma_screenshot_path, "Figma screenshot")
    when "react"
      serve_image(component.react_screenshot_path, "React screenshot")
    else
      render plain: "Unknown screenshot type", status: :bad_request
    end
  end

  # PATCH /api/components/:id
  # Update component (enable/disable, etc.)
  def update
    component = Component.find(params[:id])
    component.update!(component_params)
    render json: {
      id: component.id,
      name: component.name,
      enabled: component.enabled,
      status: component.status
    }
  end

  def figma_json
    component = Component.find(params[:id])
    render json: {
      id: component.id,
      node_id: component.node_id,
      name: component.name,
      figma_json: component.figma_json
    }
  end

  def component_set_figma_json
    component_set = ComponentSet.find(params[:id])
    default_variant = component_set.default_variant
    render json: {
      id: component_set.id,
      node_id: component_set.node_id,
      name: component_set.name,
      figma_json: default_variant&.figma_json
    }
  end

  def component_set_svg
    component_set = ComponentSet.find(params[:id])

    # Use cached SVG if available
    asset = component_set.figma_assets.svgs.first
    if asset&.content.present?
      render plain: asset.content, content_type: "image/svg+xml"
      return
    end

    # Fetch from Figma and cache
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    response = figma.export_svg(component_set.figma_file_key, component_set.node_id)
    svg_url = response.dig("images", component_set.node_id)

    if svg_url.blank?
      render plain: "<!-- SVG not available -->", content_type: "image/svg+xml"
      return
    end

    svg_content = figma.fetch_svg_content(svg_url)

    # Cache for next time
    component_set.figma_assets.find_or_initialize_by(node_id: component_set.node_id).update!(
      name: component_set.name,
      asset_type: "svg",
      content: svg_content
    )

    render plain: svg_content, content_type: "image/svg+xml"
  end

  private

  def component_params
    params.require(:component).permit(:enabled, :status, :match_percent)
  end

  def serve_image(path, label)
    if path.present? && File.exist?(path)
      send_file path, type: "image/png", disposition: "inline"
    else
      render plain: "#{label} not available", status: :not_found
    end
  end
end
