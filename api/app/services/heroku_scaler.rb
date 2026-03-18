class HerokuScaler
  # Dyno sizes ordered by memory (MB)
  DYNO_SIZES = {
    "standard-1x" => 512,
    "standard-2x" => 1024,
    "performance-m" => 2560
  }.freeze

  DEFAULT_SIZE = "standard-1x"

  def self.scale_figma_worker(size)
    new.scale_figma_worker(size)
  end

  def self.pick_dyno_size(estimated_mb)
    # Add 30% headroom over estimate
    needed = estimated_mb * 1.3
    DYNO_SIZES.each do |size, mb|
      return size if mb >= needed
    end
    "performance-m" # largest available
  end

  def scale_figma_worker(size)
    return unless api_key.present? && app_name.present?
    return unless DYNO_SIZES.key?(size)

    current = current_figma_worker_size
    if current == size
      log "figma_worker already #{size}, skipping"
      return
    end

    log "Scaling figma_worker: #{current} → #{size}"

    # Heroku Platform API: PATCH /apps/{app}/formation/{type}
    uri = URI("https://api.heroku.com/apps/#{app_name}/formation/figma_worker")
    req = Net::HTTP::Patch.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/vnd.heroku+json; version=3"
    req.body = { size: size, quantity: 1 }.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      log "Failed to scale: #{res.code} #{res.body}"
      return
    end

    log "Scaled figma_worker to #{size}"
    size
  end

  def current_figma_worker_size
    return nil unless api_key.present? && app_name.present?

    uri = URI("https://api.heroku.com/apps/#{app_name}/formation/figma_worker")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    req["Accept"] = "application/vnd.heroku+json; version=3"

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    res = http.request(req)

    return nil unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body)["size"]
  rescue => e
    log "Failed to get current size: #{e.message}"
    nil
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
