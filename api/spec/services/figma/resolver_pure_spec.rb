require "spec_helper"
require "active_support/core_ext/object/blank"

# Load only the pure service files — no Rails, no DB.
require_relative "../../../app/services/figma/ir"
require_relative "../../../app/services/figma/style_extractor"
require_relative "../../../app/services/figma/resolver"

# Lightweight stand-ins for AR models — Resolver uses duck typing.
ComponentSetData = Struct.new(:node_id, :name, :description, :figma_json, :component_key,
                              :prop_definitions, :slots, :is_root, :is_image, :is_flexgrow,
                              :is_list, :figma_file_key, :figma_file_name,
                              :validation_warnings, keyword_init: true) do
  def default_variant
    @variants&.find(&:is_default) || @variants&.first
  end

  def variants
    @variants || []
  end

  def variants=(list)
    @variants = list
  end

  def vector?
    false
  end
end

VariantData = Struct.new(:id, :node_id, :name, :figma_json, :is_default,
                         :component_key, keyword_init: true) do
  def variant_properties
    parts = name.to_s.split(", ").map { |p| k, v = p.split("="); [k&.strip&.downcase, v&.strip&.downcase] }
    parts.to_h
  end

  def component_set
    @component_set
  end

  def component_set=(cs)
    @component_set = cs
  end
end

ComponentData = Struct.new(:node_id, :name, :figma_json, :component_key,
                           :prop_definitions, :slots, :is_root, :is_image, :is_flexgrow,
                           :is_list, :figma_file_key, :figma_file_name,
                           :validation_warnings, keyword_init: true) do
  def vector?
    false
  end
end

RSpec.describe Figma::Resolver, "pure (no DB)" do
  def build_resolver(components_by_node_id: {}, component_sets_by_node_id: {},
                     variants_by_node_id: {}, node_id_to_component_set: {},
                     component_key_by_node_id: {}, variants_by_component_key: {},
                     svg_assets_by_name: {}, inline_svgs_by_node_id: {},
                     inline_pngs_by_node_id: {}, image_component_keys: Set.new,
                     figma_file_keys: Set.new)
    described_class.new({
      components_by_node_id: components_by_node_id,
      component_sets_by_node_id: component_sets_by_node_id,
      variants_by_node_id: variants_by_node_id,
      node_id_to_component_set: node_id_to_component_set,
      component_key_by_node_id: component_key_by_node_id,
      variants_by_component_key: variants_by_component_key,
      svg_assets_by_name: svg_assets_by_name,
      inline_svgs_by_node_id: inline_svgs_by_node_id,
      inline_pngs_by_node_id: inline_pngs_by_node_id,
      image_component_keys: image_component_keys,
      figma_file_keys: figma_file_keys,
    })
  end

  describe "#resolve_node" do
    it "resolves FRAME to :frame IR" do
      resolver = build_resolver
      node = { "id" => "1:1", "type" => "FRAME", "name" => "wrapper",
               "layoutMode" => "VERTICAL", "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:styles]).to include("display" => "flex", "flex-direction" => "column")
      expect(ir[:children]).to eq([])
    end

    it "resolves TEXT to :text with content" do
      resolver = build_resolver
      node = { "id" => "1:2", "type" => "TEXT", "name" => "label",
               "characters" => "Hello" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_content]).to eq("Hello")
    end

    it "resolves TEXT bound to prop as :text with text_prop" do
      resolver = build_resolver
      node = { "id" => "1:3", "type" => "TEXT", "name" => "label",
               "characters" => "Default",
               "componentPropertyReferences" => { "characters" => "title" } }
      ir = resolver.resolve_node(node, current_props: {
        "title" => { name: "title", type: "TEXT", default_value: "Default" }
      })
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_prop]).to eq("title")
    end

    it "resolves hidden node as nil" do
      resolver = build_resolver
      node = { "id" => "1:7", "type" => "FRAME", "name" => "hidden",
               "visible" => false, "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir).to be_nil
    end

    it "resolves BOOLEAN-controlled node with visibility_prop" do
      resolver = build_resolver
      node = { "id" => "1:8", "type" => "FRAME", "name" => "conditional",
               "visible" => true, "children" => [],
               "componentPropertyReferences" => { "visible" => "showHeader" } }
      ir = resolver.resolve_node(node, current_props: {
        "showHeader" => { name: "showHeader", type: "BOOLEAN", default_value: true }
      })
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:visibility_prop]).to eq("showHeader")
    end

    it "resolves VECTOR as :shape" do
      resolver = build_resolver
      node = { "id" => "1:9", "type" => "VECTOR", "name" => "divider",
               "absoluteBoundingBox" => { "width" => 100, "height" => 1 } }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:shape)
    end

    it "resolves RECTANGLE as :shape" do
      resolver = build_resolver
      node = { "id" => "1:10", "type" => "RECTANGLE", "name" => "bg",
               "absoluteBoundingBox" => { "width" => 200, "height" => 100 } }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:shape)
    end

    it "resolves FRAME with nested children recursively" do
      resolver = build_resolver
      node = { "id" => "1:1", "type" => "FRAME", "name" => "outer",
               "layoutMode" => "HORIZONTAL",
               "children" => [
                 { "id" => "1:2", "type" => "TEXT", "name" => "title", "characters" => "Hi" },
                 { "id" => "1:3", "type" => "RECTANGLE", "name" => "spacer",
                   "absoluteBoundingBox" => { "width" => 10, "height" => 10 } }
               ] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:children].size).to eq(2)
      expect(ir[:children][0][:kind]).to eq(:text)
      expect(ir[:children][1][:kind]).to eq(:shape)
    end

    it "resolves INSTANCE to :component_ref when component set exists" do
      cs = ComponentSetData.new(node_id: "cs:1", name: "Button", prop_definitions: {})
      variant = VariantData.new(id: 1, node_id: "v:1", name: "Default", is_default: true,
                                figma_json: { "id" => "v:1", "type" => "COMPONENT" })
      variant.component_set = cs
      cs.variants = [variant]

      resolver = build_resolver(
        component_sets_by_node_id: { "cs:1" => cs },
        variants_by_node_id: { "v:1" => variant },
        node_id_to_component_set: { "cs:1" => cs, "v:1" => cs }
      )

      node = { "id" => "inst:1", "type" => "INSTANCE", "name" => "button instance",
               "componentId" => "v:1" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:component_name]).to eq("Button")
    end

    it "resolves unresolvable INSTANCE to :unresolved" do
      resolver = build_resolver
      resolver.current_owner_node_id = "owner:1"
      node = { "id" => "1:5", "type" => "INSTANCE", "name" => "missing icon",
               "componentId" => "nonexistent:999" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:unresolved)
      expect(ir[:instance_name]).to eq("missing icon")
    end

    it "inlines PNG when inline_pngs_by_node_id has matching entry" do
      resolver = build_resolver(inline_pngs_by_node_id: { "1:1" => "base64data" })
      node = { "id" => "1:1", "type" => "FRAME", "name" => "photo",
               "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:png_inline)
      expect(ir[:png_data]).to eq("base64data")
    end

    it "inlines SVG for vector frames with matching entry" do
      resolver = build_resolver(inline_svgs_by_node_id: { "1:1" => "<svg>...</svg>" })
      # vector_frame? requires all children to be vector types
      node = { "id" => "1:1", "type" => "FRAME", "name" => "icon",
               "children" => [
                 { "id" => "1:2", "type" => "VECTOR", "name" => "path" }
               ] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:svg_inline)
      expect(ir[:svg_content]).to eq("<svg>...</svg>")
    end
  end

  describe "#resolve_component_set" do
    it "resolves a single-variant component set to :component IR" do
      variant_json = {
        "id" => "v:1", "type" => "COMPONENT", "name" => "Default",
        "children" => [
          { "id" => "t:1", "type" => "TEXT", "name" => "label", "characters" => "Click" }
        ]
      }
      variant = VariantData.new(id: 1, node_id: "v:1", name: "Default", is_default: true,
                                figma_json: variant_json)
      cs = ComponentSetData.new(
        node_id: "cs:1", name: "Button", prop_definitions: {},
        slots: [], is_root: false, is_image: false, is_list: false
      )
      variant.component_set = cs
      cs.variants = [variant]

      resolver = build_resolver(
        component_sets_by_node_id: { "cs:1" => cs },
        variants_by_node_id: { "v:1" => variant },
        node_id_to_component_set: { "cs:1" => cs, "v:1" => cs }
      )

      ir = resolver.resolve_component_set(cs)
      expect(ir[:kind]).to eq(:component)
      expect(ir[:react_name]).to eq("Button")
      expect(ir[:tree][:kind]).to eq(:frame)
    end

    it "resolves is_image component set to :component with is_image flag" do
      variant = VariantData.new(id: 1, node_id: "v:1", name: "Default", is_default: true,
                                figma_json: { "id" => "v:1", "type" => "COMPONENT", "children" => [] })
      cs = ComponentSetData.new(
        node_id: "cs:1", name: "Photo", prop_definitions: {},
        is_image: true
      )
      variant.component_set = cs
      cs.variants = [variant]

      resolver = build_resolver(
        component_sets_by_node_id: { "cs:1" => cs },
        variants_by_node_id: { "v:1" => variant }
      )

      ir = resolver.resolve_component_set(cs)
      expect(ir[:kind]).to eq(:component)
      expect(ir[:is_image]).to eq(true)
    end
  end

  describe "#track_unresolved_instance" do
    it "records unresolved instances by owner node" do
      resolver = build_resolver
      resolver.current_owner_node_id = "owner:1"
      resolver.track_unresolved_instance("comp:1", "MissingButton")
      resolver.track_unresolved_instance("comp:2", "MissingIcon")

      expect(resolver.unresolved_instances["owner:1"]).to contain_exactly("MissingButton", "MissingIcon")
    end

    it "does nothing when no current_owner_node_id" do
      resolver = build_resolver
      resolver.track_unresolved_instance("comp:1", "Missing")
      expect(resolver.unresolved_instances).to be_empty
    end
  end
end
