class RendersController < ApplicationController
  def show
    item = Render.find_by_token!(params[:id])

    send_data item.image,
      type: "image/png",
      disposition: :inline,
      filename: "render_#{item.id}.png"
  end
end
