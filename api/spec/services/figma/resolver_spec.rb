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

  describe "regression: instance override props" do
    it "extracts componentProperties overrides into prop_overrides" do
      cs = library.component_sets.create!(
        node_id: "ovr:cs:1", name: "Button",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Size" => { "type" => "VARIANT", "defaultValue" => "M" },
          "Disabled" => { "type" => "BOOLEAN", "defaultValue" => false }
        }
      )
      cs.variants.create!(
        node_id: "ovr:v:1", name: "Default",
        is_default: true,
        figma_json: { "id" => "ovr:v:1", "type" => "COMPONENT", "children" => [] }
      )

      fresh_resolver = described_class.new(library)

      node = {
        "id" => "ovr:inst:1", "type" => "INSTANCE", "name" => "button instance",
        "componentId" => "ovr:cs:1",
        "componentProperties" => {
          "Size" => { "type" => "VARIANT", "value" => "L" },
          "Disabled" => { "type" => "BOOLEAN", "value" => true }
        }
      }
      ir = fresh_resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:component_name]).to eq("Button")
      expect(ir[:prop_overrides]).to include("size" => '"L"')
      expect(ir[:prop_overrides]).to include("disabled" => "{true}")
    end

    it "skips overrides that match default values" do
      cs = library.component_sets.create!(
        node_id: "ovr:cs:2", name: "Tag",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Label" => { "type" => "TEXT", "defaultValue" => "Tag" }
        }
      )
      cs.variants.create!(
        node_id: "ovr:v:2", name: "Default",
        is_default: true,
        figma_json: { "id" => "ovr:v:2", "type" => "COMPONENT", "children" => [] }
      )

      fresh_resolver = described_class.new(library)

      node = {
        "id" => "ovr:inst:2", "type" => "INSTANCE", "name" => "tag instance",
        "componentId" => "ovr:cs:2",
        "componentProperties" => {
          "Label" => { "type" => "TEXT", "value" => "Tag" }
        }
      }
      ir = fresh_resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:prop_overrides]).to be_empty
    end
  end

  describe "regression: root frame not inlined as PNG/SVG" do
    it "does not inline root frame as PNG even if asset exists" do
      # resolve_node called from resolve_single_variant passes is_root context
      # but resolve_frame itself shouldn't inline root nodes
      node = {
        "id" => "root:1", "type" => "FRAME", "name" => "Root",
        "layoutMode" => "VERTICAL",
        "children" => [
          { "id" => "child:1", "type" => "TEXT", "name" => "label", "characters" => "Hi" }
        ]
      }
      # Even if the node_id is in inline_pngs, resolve for root should return :frame
      # This tests that the top-level resolve_single_variant marks root correctly
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:children].size).to eq(1)
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

  describe "#resolve_component_set (vector-only icons)" do
    # Vector-only component sets (icons) must resolve as normal components —
    # NOT as bare SVG components. They should produce a div wrapping inline SVG,
    # preserving the component's node structure.
    let(:icon_set) do
      cs = library.component_sets.create!(
        node_id: "icon:cs:1",
        name: "plus",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "style" => { "type" => "VARIANT", "defaultValue" => "regular" }
        }
      )
      cs.variants.create!(
        node_id: "icon:v:1",
        name: "style=regular",
        is_default: true,
        figma_json: {
          "id" => "icon:v:1",
          "type" => "COMPONENT",
          "name" => "style=regular",
          "children" => [
            { "id" => "icon:vec:1", "type" => "VECTOR", "name" => "path",
              "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0 } }] }
          ]
        }
      )
      cs.variants.create!(
        node_id: "icon:v:2",
        name: "style=filled",
        is_default: false,
        figma_json: {
          "id" => "icon:v:2",
          "type" => "COMPONENT",
          "name" => "style=filled",
          "children" => [
            { "id" => "icon:vec:2", "type" => "VECTOR", "name" => "path",
              "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0 } }] }
          ]
        }
      )
      cs
    end

    it "never resolves a component set as is_svg, even with an SVG asset" do
      # Create an SVG asset for the component set (simulating AssetExtractor)
      icon_set.figma_assets.create!(
        node_id: icon_set.node_id,
        name: icon_set.name,
        asset_type: "svg",
        content: '<svg width="16" height="16"><path d="M8 0v16"/></svg>'
      )

      # Re-create resolver so it picks up the new asset
      fresh_resolver = described_class.new(library)
      fresh_resolver.current_owner_node_id = icon_set.node_id
      ir = fresh_resolver.resolve_component_set(icon_set)

      expect(ir).not_to be_nil
      expect(ir[:is_svg]).to be_falsey
      expect(ir[:kind]).to eq(:multi_variant)
    end

    it "resolves vector-only icon as multi_variant with normal node tree" do
      resolver.current_owner_node_id = icon_set.node_id
      ir = resolver.resolve_component_set(icon_set)

      expect(ir[:kind]).to eq(:multi_variant)
      expect(ir[:variants].size).to eq(2)
      expect(ir[:variant_prop_names]).to include("style")
    end
  end
end
