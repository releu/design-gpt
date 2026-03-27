class FigmaMcpCredential < ApplicationRecord
  # Single-row table storing the Figma MCP OAuth token (mcp:connect scope).
  # Token was issued by Claude's registered OAuth client.

  def self.current
    first
  end

  def self.current_token
    cred = current
    return nil unless cred

    if cred.expires_at && cred.expires_at < Time.current
      cred.refresh!
    end

    cred.access_token
  end

  def refresh!
    return unless refresh_token.present?

    client_id = ENV.fetch("FIGMA_MCP_OAUTH_CLIENT_ID")
    client_secret = ENV.fetch("FIGMA_MCP_OAUTH_CLIENT_SECRET")

    uri = URI.parse("https://api.figma.com/v1/oauth/refresh")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Authorization"] = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
    request.body = URI.encode_www_form(refresh_token: refresh_token)

    response = http.request(request)
    data = JSON.parse(response.body)

    if data["access_token"]
      update!(
        access_token: data["access_token"],
        expires_at: data["expires_in"] ? Time.current + data["expires_in"].to_i : nil
      )
    else
      Rails.logger.error("Figma MCP token refresh failed: #{data}")
    end
  end
end
