require "net/http"
require "json"
require "uri"
require "securerandom"

module Figma
  # Direct HTTP client for Figma MCP server (Streamable HTTP transport).
  # Uses mcp:connect scoped OAuth token.
  class McpClient
    class McpError < StandardError; end

    DEFAULT_URL = "https://mcp.figma.com/mcp"
    CALL_TIMEOUT = 120

    def initialize(url: nil, token: nil)
      @url = url || ENV.fetch("FIGMA_MCP_URL", DEFAULT_URL)
      @token = token || FigmaMcpCredential.current_token or raise McpError, "No Figma MCP token configured"
    end

    def use_figma(file_key:, code:, description: "Render design")
      call_tool("use_figma", {
        fileKey: file_key,
        code: code,
        description: description
      })
    end

    private

    def call_tool(tool_name, arguments)
      # Initialize handshake
      rpc_post(build_rpc("initialize", {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "design-gpt", version: "1.0" }
      }))

      # Notify initialized
      rpc_post({
        jsonrpc: "2.0",
        method: "notifications/initialized"
      })

      # Call the tool
      result = rpc_post(build_rpc("tools/call", {
        name: tool_name,
        arguments: arguments
      }))

      if result["error"]
        raise McpError, "MCP error: #{result["error"]["message"]}"
      end

      result["result"]
    end

    def build_rpc(method, params)
      {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: method,
        params: params
      }
    end

    def rpc_post(payload)
      uri = URI.parse(@url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = CALL_TIMEOUT
      http.read_timeout = CALL_TIMEOUT

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json, text/event-stream"
      request["Authorization"] = "Bearer #{@token}"
      request["Mcp-Session-Id"] = @last_session_id if @last_session_id
      request.body = payload.to_json

      response = http.request(request)

      if response["mcp-session-id"]
        @last_session_id = response["mcp-session-id"]
      end

      unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPAccepted)
        raise McpError, "MCP failed: HTTP #{response.code} — #{response.body&.truncate(500)}"
      end

      return {} if response.body.blank?

      if response["content-type"]&.include?("text/event-stream")
        parse_sse_response(response.body)
      else
        JSON.parse(response.body)
      end
    rescue JSON::ParserError
      {}
    end

    def parse_sse_response(body)
      result = {}
      body.each_line do |line|
        line = line.chomp
        if line.start_with?("data:")
          data = line.sub("data:", "").strip
          next if data.empty?
          parsed = JSON.parse(data) rescue next
          result = parsed if parsed["id"] || parsed["result"]
        end
      end
      result
    end
  end
end
