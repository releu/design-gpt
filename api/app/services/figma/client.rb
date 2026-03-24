# app/services/figma/client.rb
require "net/http"
require "json"

module Figma
  class Client
    class RateLimitError < StandardError; end
    class ApiError < StandardError; end

    MAX_RETRIES = 5
    CACHE_DIR = Rails.root.join("tmp", "figma_cache")

    def initialize(token)
      @token = token
    end

    # Enable/disable local file caching for API responses.
    # When enabled, GET responses are cached in tmp/figma_cache/.
    # Full file fetches check lastModified before re-downloading.
    def self.cache_enabled?
      @cache_enabled.nil? ? true : @cache_enabled
    end

    def self.cache_enabled=(val)
      @cache_enabled = val
    end

    def get(path)
      return get_uncached(path) unless self.class.cache_enabled?

      cache_hash = Digest::SHA256.hexdigest(path)[0..31]
      # Keep a short readable prefix for debugging
      prefix = path.split("/").last(2).join("_").gsub(/[^a-zA-Z0-9._-]/, "_")[0..40]
      cache_key = "#{prefix}_#{cache_hash}"
      cache_path = CACHE_DIR.join("#{cache_key}.json")
      meta_path = CACHE_DIR.join("#{cache_key}.meta")
      FileUtils.mkdir_p(CACHE_DIR)

      # For full file fetches, check lastModified with cheap depth=1 call
      if path.match?(%r{^/v1/files/[^/]+$}) && cache_path.exist?
        file_key = path.split("/").last
        cached_modified = meta_path.exist? ? File.read(meta_path).strip : nil
        if cached_modified
          begin
            light = get_uncached("/v1/files/#{file_key}?depth=1")
            current_modified = light["lastModified"]
            if current_modified == cached_modified
              puts "[Figma::Client] Cache hit for #{path} (lastModified: #{cached_modified})"
              return JSON.parse(File.read(cache_path))
            else
              puts "[Figma::Client] Cache stale for #{path} (#{cached_modified} → #{current_modified})"
            end
          rescue => e
            puts "[Figma::Client] Cache check failed: #{e.message}, fetching fresh"
          end
        end
      elsif cache_path.exist?
        # For non-file endpoints (images, components, etc.) — use simple TTL cache (1 hour)
        if (Time.now - File.mtime(cache_path)) < 3600
          puts "[Figma::Client] Cache hit for #{path}"
          return JSON.parse(File.read(cache_path))
        end
      end

      # Fetch fresh
      result = get_uncached(path)

      # Write cache
      File.write(cache_path, JSON.generate(result))
      if path.match?(%r{^/v1/files/[^/]+$}) && result["lastModified"]
        File.write(meta_path, result["lastModified"])
      end

      result
    end

    def get_uncached(path)
      uri = URI("https://api.figma.com#{path}")
      req = Net::HTTP::Get.new(uri)
      req["X-Figma-Token"] = @token

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      http.open_timeout = 30
      http.read_timeout = 300  # 5 minutes for large files

      attempt = 0
      begin
        attempt += 1
        res = http.request(req)

        case res.code.to_i
        when 200
          JSON.parse(res.body)
        when 429
          wait = (res["Retry-After"] || (attempt * 10)).to_i
          puts "[Figma::Client] Rate limited (429). Waiting #{wait}s... (attempt #{attempt}/#{MAX_RETRIES})"
          sleep(wait)
          raise RateLimitError, "Rate limited"
        when 500..599
          puts "[Figma::Client] Server error #{res.code}. Retrying in #{attempt * 2}s..."
          sleep(attempt * 2)
          raise ApiError, "Server error #{res.code}"
        else
          raise ApiError, "HTTP #{res.code}: #{res.body.to_s[0..200]}"
        end
      rescue RateLimitError, ApiError => e
        retry if attempt < MAX_RETRIES
        raise e
      rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
        if attempt < MAX_RETRIES
          sleep(attempt * 0.5)
          retry
        end
        raise e
      end
    end

    # Lightweight metadata — counts components without downloading the full document tree
    def file_component_counts(file_key)
      components = get("/v1/files/#{file_key}/components")
      component_sets = get("/v1/files/#{file_key}/component_sets")
      {
        components: (components.dig("meta", "components") || []).size,
        component_sets: (component_sets.dig("meta", "component_sets") || []).size
      }
    end

    def component(key)
      get("/v1/components/#{key}")
    end

    def nodes(file_key, ids)
      get("/v1/files/#{file_key}/nodes?ids=#{Array(ids).join(",")}")
    end

    def export_svg(file_key, node_ids)
      ids = Array(node_ids).map { |id| URI.encode_www_form_component(id) }.join(",")
      get("/v1/images/#{file_key}?ids=#{ids}&format=svg")
    end

    def export_png(file_key, node_ids, scale: 2)
      ids = Array(node_ids).map { |id| URI.encode_www_form_component(id) }.join(",")
      get("/v1/images/#{file_key}?ids=#{ids}&format=png&scale=#{scale}")
    end

    # Download content from a URL (SVG text or PNG binary from Figma CDN)
    def fetch_svg_content(url, retries: MAX_RETRIES)
      fetch_content(url, retries: retries)
    end

    def fetch_binary_content(url, retries: MAX_RETRIES)
      fetch_content(url, retries: retries)
    end

    private

    def fetch_content(url, retries: MAX_RETRIES)
      if self.class.cache_enabled?
        cache_key = Digest::SHA256.hexdigest(url)[0..31]
        cache_path = CACHE_DIR.join("cdn_#{cache_key}.bin")
        FileUtils.mkdir_p(CACHE_DIR)
        if cache_path.exist? && (Time.now - File.mtime(cache_path)) < 86400
          return File.binread(cache_path)
        end
        result = fetch_content_uncached(url, retries: retries)
        File.binwrite(cache_path, result)
        return result
      end
      fetch_content_uncached(url, retries: retries)
    end

    def fetch_content_uncached(url, retries: MAX_RETRIES)
      uri = URI(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      http.open_timeout = 10
      http.read_timeout = 30

      attempt = 0
      begin
        attempt += 1
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)

        case res.code.to_i
        when 200
          res.body
        when 429
          wait = (res["Retry-After"] || (attempt * 5)).to_i
          puts "[Figma::Client] CDN rate limited. Waiting #{wait}s..."
          sleep(wait)
          raise RateLimitError
        when 500..599
          sleep(attempt * 1)
          raise ApiError, "CDN #{res.code}"
        else
          raise ApiError, "CDN HTTP #{res.code}"
        end
      rescue RateLimitError, ApiError => e
        retry if attempt < retries
        raise e
      rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
        if attempt < retries
          sleep(attempt * 0.5)
          retry
        end
        raise e
      end
    end
  end
end
