class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def health_check
    head :ok
  end

  def spa_fallback
    file = Rails.public_path.join("index.html")
    if file.exist?
      render file: file, layout: false, content_type: "text/html"
    else
      head :not_found
    end
  end

  private

  def not_found
    head :not_found
  end

  def current_user
    return @current_user if defined?(@current_user)

    token = request.headers["Authorization"]&.split(" ", 2)&.last
    return nil unless token

    payload = Auth0Service.decode_token(token)
    return nil unless payload&.dig("sub")

    auth0_id = payload["sub"]
    @current_user = User.find_by(auth0_id: auth0_id)
    return @current_user if @current_user

    username = payload["nickname"] || payload["name"] || payload["email"]&.split("@")&.first || auth0_id
    username = "#{username}-#{auth0_id.split('|').last}" if User.exists?(username: username)

    attrs = { auth0_id: auth0_id, username: username }
    attrs[:email] = payload["email"] if payload["email"]
    @current_user = User.create!(attrs)
  rescue ActiveRecord::RecordNotUnique
    @current_user = User.find_by(auth0_id: auth0_id)
  rescue ActiveRecord::RecordInvalid
    @current_user = User.find_by(auth0_id: auth0_id)
  end

  def require_auth
    head(:unauthorized) unless current_user
  end
end
