# app/services/figma/client.rb
require "net/http"
require "json"

module Figma
  class Client
    def initialize(token)
      @token = token
    end

    def get(path)
      uri = URI("https://api.figma.com#{path}")
      req = Net::HTTP::Get.new(uri)
      req["X-Figma-Token"] = @token

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      http.open_timeout = 30
      http.read_timeout = 300  # 5 minutes for large files

      res = http.request(req)
      JSON.parse(res.body)
    end

    # Lightweight metadata call — returns component/variant counts without the full document tree
    def file_meta(file_key)
      get("/v1/files/#{file_key}?depth=1")
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

    # Download binary content from a URL (for PNG exports, etc.)
    def fetch_binary_content(url, retries: 3)
      uri = URI(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      http.open_timeout = 10
      http.read_timeout = 30

      attempts = 0
      begin
        attempts += 1
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        res.body
      rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
        if attempts < retries
          sleep(attempts * 0.5)
          retry
        else
          raise e
        end
      end
    end

    def fetch_svg_content(url, retries: 3)
      uri = URI(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      http.open_timeout = 10
      http.read_timeout = 30

      attempts = 0
      begin
        attempts += 1
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        res.body
      rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
        if attempts < retries
          sleep_time = attempts * 0.5  # 0.5s, 1s, 1.5s backoff
          sleep(sleep_time)
          retry
        else
          raise e
        end
      end
    end
  end
end
