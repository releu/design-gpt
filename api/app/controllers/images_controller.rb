class ImagesController < ApplicationController
  before_action :require_auth

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
end
