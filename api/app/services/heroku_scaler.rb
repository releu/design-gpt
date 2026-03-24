class HerokuScaler
  FIGMA_WORKER_SIZE = "performance-l"

  def self.scale(process, quantity:, size: nil)
    new.scale(process, quantity: quantity, size: size)
  end

  def self.scale_up_figma_worker
    scale("figma_worker", quantity: 1, size: FIGMA_WORKER_SIZE)
  end

  def self.scale_down_figma_worker
    scale("figma_worker", quantity: 0)
  end

  def scale(process, quantity:, size: nil)
    return unless api_key.present? && app_name.present?

    body = { quantity: quantity }
    body[:size] = size if size

    log "Scaling #{process}: quantity=#{quantity}#{size ? " size=#{size}" : ""}"

    uri = URI("https://api.heroku.com/apps/#{app_name}/formation/#{process}")
    req = Net::HTTP::Patch.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/vnd.heroku+json; version=3"
    req.body = body.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      log "Failed to scale #{process}: #{res.code} #{res.body}"
      return
    end

    log "Scaled #{process} to quantity=#{quantity}#{size ? " size=#{size}" : ""}"
    true
  end

  private

  def api_key
    ENV["HEROKU_API_KEY"]
  end

  def app_name
    ENV["HEROKU_APP_NAME"]
  end

  def log(message)
    puts "[HerokuScaler] #{message}"
  end
end
