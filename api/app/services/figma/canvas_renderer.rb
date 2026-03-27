module Figma
  class CanvasRenderer
    RENDERER_JS_PATH = Rails.root.join("lib/figma/mcp-renderer.js").freeze

    def initialize(mcp_client: nil)
      @mcp_client = mcp_client || McpClient.new
    end

    # Render a design's current iteration to Figma canvas.
    # Returns the MCP response (frame ID, dimensions, etc.)
    def render(design, file_key:)
      iteration = design.iterations.order(:id).last
      raise "No iteration to render" unless iteration&.tree

      tree = enrich_tree(design, iteration.tree)
      code = build_code(tree, design.name)

      @mcp_client.use_figma(
        file_key: file_key,
        code: code,
        description: "Render design '#{design.name}' from Design GPT"
      )
    end

    private

    def enrich_tree(design, tree)
      return tree unless design.design_system
      Exports::FigmaTreeBuilder.new(design).build(tree)
    end

    def build_code(tree, name)
      renderer_js = self.class.renderer_js
      tree_json = tree.to_json
      name_json = name.to_json

      # Inject tree and name as globals before the IIFE executes
      "var __TREE__ = #{tree_json};\nvar __NAME__ = #{name_json};\n#{renderer_js}"
    end

    def self.renderer_js
      @renderer_js ||= File.read(RENDERER_JS_PATH)
    end

    # Clear cached JS (useful after rebuilding the bundle)
    def self.clear_cache!
      @renderer_js = nil
    end
  end
end
