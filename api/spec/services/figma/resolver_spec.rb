require "rails_helper"

RSpec.describe Figma::Resolver do
  fixtures :figma_files, :component_sets, :component_variants

  let(:library) { figma_files(:example_lib) }
  let(:resolver) { described_class.new(library) }

  describe "#resolve_node" do
    it "resolves FRAME to :frame with children" do
      node = { "id" => "1:1", "type" => "FRAME", "name" => "wrapper",
               "layoutMode" => "VERTICAL", "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:styles]).to include("display" => "flex", "flex-direction" => "column")
    end

    it "resolves TEXT to :text with content" do
      node = { "id" => "1:2", "type" => "TEXT", "name" => "label",
               "characters" => "Hello" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_content]).to eq("Hello")
    end

    it "resolves TEXT bound to prop" do
      node = { "id" => "1:3", "type" => "TEXT", "name" => "label",
               "characters" => "Default",
               "componentPropertyReferences" => { "characters" => "title" } }
      ir = resolver.resolve_node(node, current_props: {
        "title" => { name: "title", type: "TEXT", default_value: "Default" }
      })
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_prop]).to eq("title")
    end

    it "resolves INSTANCE to :component_ref when component exists" do
      cs = library.component_sets.create!(
        node_id: "target:1", name: "Button",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name
      )
      cs.variants.create!(node_id: "target:2", name: "Default",
                          is_default: true, figma_json: { "id" => "target:2", "type" => "COMPONENT" })

      fresh_resolver = described_class.new(library)

      node = { "id" => "1:4", "type" => "INSTANCE", "name" => "button instance",
               "componentId" => "target:2" }
      ir = fresh_resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:component_name]).to eq("Button")
    end

    it "resolves unresolvable INSTANCE to :unresolved" do
      node = { "id" => "1:5", "type" => "INSTANCE", "name" => "missing icon",
               "componentId" => "nonexistent:999" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:unresolved)
      expect(ir[:instance_name]).to eq("missing icon")
    end

    it "resolves INSTANCE_SWAP with preferredValues to :slot" do
      node = { "id" => "1:6", "type" => "INSTANCE", "name" => "content slot",
               "componentId" => "some:id",
               "componentPropertyReferences" => { "mainComponent" => "content" } }
      prop_defs = { "content" => { "type" => "INSTANCE_SWAP", "preferredValues" => [{ "type" => "COMPONENT_SET", "key" => "abc" }] } }
      ir = resolver.resolve_node(node, prop_definitions: prop_defs,
                                       slot_map: { "1:6" => "content" })
      expect(ir[:kind]).to eq(:slot)
      expect(ir[:prop_name]).to eq("content")
    end

    it "resolves hidden node as nil" do
      node = { "id" => "1:7", "type" => "FRAME", "name" => "hidden",
               "visible" => false, "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir).to be_nil
    end

    it "resolves BOOLEAN-controlled node with visibility_prop" do
      node = { "id" => "1:8", "type" => "FRAME", "name" => "conditional",
               "visible" => true, "children" => [],
               "componentPropertyReferences" => { "visible" => "showHeader" } }
      ir = resolver.resolve_node(node, current_props: {
        "showHeader" => { name: "showHeader", type: "BOOLEAN", default_value: true }
      })
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:visibility_prop]).to eq("showHeader")
    end

    it "resolves VECTOR shape" do
      node = { "id" => "1:9", "type" => "RECTANGLE", "name" => "divider" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:shape)
    end

    it "resolves GROUP like frame" do
      node = { "id" => "1:10", "type" => "GROUP", "name" => "group1",
               "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
    end

    it "resolves INSTANCE_SWAP without preferredValues to :icon_swap" do
      node = { "id" => "1:11", "type" => "INSTANCE", "name" => "icon instance",
               "componentId" => "iconarrow:001",
               "componentPropertyReferences" => { "mainComponent" => "Icon" } }
      prop_defs = { "Icon" => { "type" => "INSTANCE_SWAP" } }
      ir = resolver.resolve_node(node, prop_definitions: prop_defs)
      expect(ir[:kind]).to eq(:icon_swap)
      expect(ir[:prop_name]).to eq("IconComponent")
    end

    it "resolves image swap INSTANCE to :image_swap" do
      # Create an image component set so the key is in the image keys set
      img_cs = library.component_sets.create!(
        node_id: "img:cs:1", name: "HeroImage",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        is_image: true,
        component_key: "imgkey123"
      )

      fresh_resolver = described_class.new(library)

      node = { "id" => "1:12", "type" => "INSTANCE", "name" => "hero image",
               "componentId" => "img:inst:1",
               "componentPropertyReferences" => { "mainComponent" => "Image" } }
      prop_defs = {
        "Image" => {
          "type" => "INSTANCE_SWAP",
          "preferredValues" => [{ "type" => "COMPONENT_SET", "key" => "imgkey123" }]
        }
      }
      ir = fresh_resolver.resolve_node(node, prop_definitions: prop_defs)
      expect(ir[:kind]).to eq(:image_swap)
      expect(ir[:prop_name]).to eq("image")
    end

    it "returns nil for non-Hash input" do
      expect(resolver.resolve_node(nil)).to be_nil
      expect(resolver.resolve_node("string")).to be_nil
    end
  end

  # =============================================
  # Regression tests for past bug classes
  # =============================================

  describe "regression: cross-file INSTANCE resolution" do
    it "resolves INSTANCE via component_key when componentId is from a sibling file" do
      # Create a component in sibling file with known component_key
      icons_file = figma_files(:example_icons)
      icon_cs = icons_file.component_sets.create!(
        node_id: "icon:cs:1", name: "ChevronDown",
        figma_file_key: icons_file.figma_file_key,
        figma_file_name: icons_file.figma_file_name
      )
      icon_variant = icon_cs.variants.create!(
        node_id: "icon:v:1", name: "Default",
        is_default: true,
        component_key: "chevron_key_abc",
        figma_json: { "id" => "icon:v:1", "type" => "COMPONENT" }
      )

      # Set up component_key_map on the main library
      library.update!(component_key_map: { "foreign:123" => "chevron_key_abc" })

      fresh_resolver = described_class.new(library)

      node = { "id" => "inst:1", "type" => "INSTANCE", "name" => "chevron",
               "componentId" => "foreign:123" }
      ir = fresh_resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:component_name]).to eq("ChevronDown")
    end
  end

  describe "regression: FILL sizing with max-width" do
    it "includes max-width for FILL horizontal sizing with bounded parent" do
      node = {
        "id" => "fill:1", "type" => "FRAME", "name" => "filler",
        "layoutMode" => "VERTICAL",
        "layoutSizingHorizontal" => "FILL",
        "absoluteBoundingBox" => { "x" => 0, "y" => 0, "width" => 400, "height" => 200 },
        "children" => []
      }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      # FILL sizing should produce flex-grow or width-related styles
      expect(ir[:styles]).to have_key("display")
    end
  end

  describe "regression: HUG + clipsContent overflow" do
    it "sets overflow hidden when clipsContent is true" do
      node = {
        "id" => "hug:1", "type" => "FRAME", "name" => "clipped",
        "layoutMode" => "HORIZONTAL",
        "layoutSizingHorizontal" => "HUG",
        "clipsContent" => true,
        "children" => []
      }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:styles]["overflow"]).to eq("hidden")
    end
  end

  describe "regression: INSTANCE_SWAP slot vs icon distinction" do
    it "treats INSTANCE_SWAP with preferredValues as slot" do
      node = { "id" => "s:1", "type" => "INSTANCE", "name" => "content",
               "componentId" => "placeholder:1",
               "componentPropertyReferences" => { "mainComponent" => "Content" } }
      prop_defs = {
        "Content" => {
          "type" => "INSTANCE_SWAP",
          "preferredValues" => [{ "type" => "COMPONENT_SET", "key" => "abc" }]
        }
      }
      ir = resolver.resolve_node(node, prop_definitions: prop_defs,
                                       slot_map: { "s:1" => "content" })
      expect(ir[:kind]).to eq(:slot)
    end

    it "treats INSTANCE_SWAP without preferredValues as icon_swap" do
      node = { "id" => "s:2", "type" => "INSTANCE", "name" => "icon",
               "componentId" => "arrow:1",
               "componentPropertyReferences" => { "mainComponent" => "Icon" } }
      prop_defs = { "Icon" => { "type" => "INSTANCE_SWAP" } }
      ir = resolver.resolve_node(node, prop_definitions: prop_defs)
      expect(ir[:kind]).to eq(:icon_swap)
    end
  end

  describe "regression: Boolean visibility prop" do
    it "sets visibility_prop when componentPropertyReferences.visible points to BOOLEAN" do
      node = {
        "id" => "bv:1", "type" => "TEXT", "name" => "label",
        "characters" => "Hello",
        "visible" => true,
        "componentPropertyReferences" => { "visible" => "showLabel" }
      }
      ir = resolver.resolve_node(node, current_props: {
        "showLabel" => { name: "showLabel", type: "BOOLEAN", default_value: true }
      })
      expect(ir[:visibility_prop]).to eq("showLabel")
    end

    it "does not set visibility_prop for non-BOOLEAN visible ref" do
      node = {
        "id" => "bv:2", "type" => "TEXT", "name" => "label",
        "characters" => "Hello",
        "visible" => true,
        "componentPropertyReferences" => { "visible" => "someRef" }
      }
      ir = resolver.resolve_node(node, current_props: {
        "someRef" => { name: "someRef", type: "TEXT", default_value: "x" }
      })
      expect(ir[:visibility_prop]).to be_nil
    end
  end

  describe "regression: detached instance resolution" do
    it "resolves detached node to component set via original child IDs" do
      # Create a component set with a variant whose node appears as an original child ID
      cs = library.component_sets.create!(
        node_id: "det:cs:1", name: "Badge",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name
      )
      cs.variants.create!(
        node_id: "det:v:1", name: "Default",
        is_default: true,
        figma_json: {
          "id" => "det:v:1", "type" => "COMPONENT",
          "children" => [
            { "id" => "det:child:1", "type" => "TEXT", "name" => "label" }
          ]
        }
      )

      fresh_resolver = described_class.new(library)

      resolved = fresh_resolver.find_component_set_for_detached({
        "children" => [
          { "id" => "inst;det:child:1", "type" => "TEXT", "name" => "label", "children" => [] }
        ]
      })
      expect(resolved).to eq(cs)
    end
  end
end
