class ImagesController < ApplicationController
  before_action :require_auth, only: :index

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
    redirect_to result[:url], allow_other_host: true
  rescue => e
    Rails.logger.error("Image render failed: #{e.message}")
    head(:not_found)
  end
end
