class ImagesController < ApplicationController
  before_action :require_auth, only: :index
  before_action :set_cors_headers, only: :render_image

  def index
    if params[:q].blank?
      render json: { results: [] }
      return
    end

    render json: ImageCache.search(params[:q])
  rescue => e
    Rails.logger.error("Image search failed: #{e.message}")
    render json: { results: [], error: "Search failed" }
  end

  def render_image
    prompt = params[:prompt].to_s.strip
    head(:bad_request) and return if prompt.blank?

    result = ImageCache.search(prompt)

    # Proxy image bytes to avoid CORS issues with cross-origin redirects
    # (Figma plugin iframe can't follow 302 to external domains)
    image_response = HTTP.get(result[:url])
    send_data image_response.body.to_s,
      type: image_response.content_type&.mime_type || "image/jpeg",
      disposition: "inline"
  rescue => e
    Rails.logger.error("Image render failed: #{e.message}")
    head(:not_found)
  end

  private

  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"] = "*"
  end
end
