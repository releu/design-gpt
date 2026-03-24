module Figma
  # Round-robin token pool for distributing Figma API requests across multiple tokens.
  # Each token has its own rate limit bucket, so using N tokens gives ~N× throughput.
  #
  # Usage:
  #   pool = Figma::TokenPool.instance
  #   client = pool.next_client  # returns a Figma::Client with the next token
  #
  # Configuration:
  #   FIGMA_TOKENS=token1,token2,token3  (comma-separated, preferred)
  #   FIGMA_TOKEN=single_token           (fallback)
  #
  class TokenPool
    include Singleton

    def initialize
      tokens_str = ENV["FIGMA_TOKENS"] || ENV["FIGMA_TOKEN"] || ""
      @tokens = tokens_str.split(",").map(&:strip).reject(&:empty?)
      @index = Concurrent::AtomicFixnum.new(0)

      if @tokens.empty?
        puts "[Figma::TokenPool] WARNING: No FIGMA_TOKEN(S) configured"
      elsif @tokens.size > 1
        puts "[Figma::TokenPool] Initialized with #{@tokens.size} tokens"
      end
    end

    def next_client
      return Figma::Client.new(@tokens.first) if @tokens.size <= 1

      idx = @index.increment % @tokens.size
      Figma::Client.new(@tokens[idx])
    end

    # Primary client (first token) — used for non-parallelizable API calls
    def primary_client
      Figma::Client.new(@tokens.first || "")
    end

    def size
      @tokens.size
    end
  end
end
