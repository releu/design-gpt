module Figma
  class CanvasRenderer
    RENDERER_JS_PATH = Rails.root.join("lib/figma/mcp-renderer.js").freeze

    def initialize(mcp_client: nil)
      @mcp_client = mcp_client || McpClient.new
    end

    # Render a design's current iteration to Figma canvas.
    def render(design, file_key:)
      iteration = design.iterations.order(:id).last
      raise "No iteration to render" unless iteration&.tree

      tree = enrich_tree(design, iteration.tree)
      code = build_code(tree, design.name)

      # Render (may timeout but frame still gets created)
      @mcp_client.use_figma(
        file_key: file_key,
        code: code,
        description: "Render design '#{design.name}'"
      )

      # Get frame info in a separate fast call
      frame_info = get_frame_info(file_key, design.name)

      if frame_info
        iteration.update!(
          figma_frame_id: frame_info["id"],
          figma_file_key: file_key
        )
      end

      {
        file_key: file_key,
        frame_id: frame_info&.dig("id"),
        embed_url: iteration.reload.figma_embed_url,
        width: frame_info&.dig("w"),
        height: frame_info&.dig("h")
      }
    end

    private

    def get_frame_info(file_key, name)
      escaped = name.gsub('"', '\\"')
      result = @mcp_client.use_figma(
        file_key: file_key,
        code: "const f = figma.currentPage.children.find(n => n.name === \"#{escaped}\"); return f ? JSON.stringify({id: f.id, w: Math.round(f.width), h: Math.round(f.height)}) : 'null';",
        description: "Get frame info"
      )
      text = result.dig("content", 0, "text")
      text ? (JSON.parse(text) rescue nil) : nil
    end

    def enrich_tree(design, tree)
      return tree unless design.design_system
      Exports::FigmaTreeBuilder.new(design).build(tree)
    end

    def build_code(tree, name)
      "var __TREE__ = #{tree.to_json};\nvar __NAME__ = #{name.to_json};\n#{self.class.renderer_js}"
    end

    def self.renderer_js
      return File.read(RENDERER_JS_PATH) if Rails.env.development?
      @renderer_js ||= File.read(RENDERER_JS_PATH)
    end

    def self.clear_cache!
      @renderer_js = nil
    end
  end
end
