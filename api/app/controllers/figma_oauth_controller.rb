class FigmaOauthController < ApplicationController
  # GET /api/figma-oauth/authorize
  # Redirects to Figma's consent screen.
  def authorize
    params = {
      client_id: ENV.fetch("FIGMA_OAUTH_CLIENT_ID"),
      redirect_uri: callback_url,
      scope: "file_content:read,file_dev_resources:read,file_dev_resources:write",
      state: SecureRandom.hex(16),
      response_type: "code"
    }

    redirect_to "https://www.figma.com/oauth?#{params.to_query}", allow_other_host: true
  end

  # GET /api/figma-oauth/callback
  # Exchanges code for token, stores it.
  def callback
    code = params[:code]
    if code.blank?
      return render plain: "Missing code parameter", status: :bad_request
    end

    uri = URI.parse("https://api.figma.com/v1/oauth/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Authorization"] = "Basic #{Base64.strict_encode64("#{ENV['FIGMA_OAUTH_CLIENT_ID']}:#{ENV['FIGMA_OAUTH_CLIENT_SECRET']}")}"
    request.body = URI.encode_www_form(
      redirect_uri: callback_url,
      code: code,
      grant_type: "authorization_code"
    )

    response = http.request(request)
    data = JSON.parse(response.body)

    if data["access_token"]
      cred = FigmaMcpCredential.first_or_initialize
      cred.update!(
        access_token: data["access_token"],
        refresh_token: data["refresh_token"],
        expires_at: data["expires_in"] ? Time.current + data["expires_in"].to_i : nil
      )

      render plain: "Figma connected! Token stored. You can close this tab."
    else
      render plain: "OAuth failed: #{data.to_json}", status: :unprocessable_entity
    end
  end

  private

  def callback_url
    "#{request.protocol}#{request.host_with_port}/api/figma-oauth/callback"
  end
end
