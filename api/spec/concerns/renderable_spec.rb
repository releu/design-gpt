require "rails_helper"

# Minimal test harness to exercise the Renderable concern in isolation.
class RenderableHost
  include Renderable
  # Renderable includes ComponentNaming via `include ComponentNaming`
end

RSpec.describe Renderable do
  fixtures :figma_files, :component_sets, :component_variants

  let(:host) { RenderableHost.new }
  let(:library) { figma_files(:example_lib) }
  let(:button_set) { component_sets(:button_set) }

  # Helper: build a component set with per-variant compiled code matching
  # what ReactFactory would produce (namespaced function names).
  def build_component_set_with_variants(lib, name:, variants:, prop_definitions:)
    cs = lib.component_sets.create!(
      node_id: "test:#{SecureRandom.hex(4)}",
      name: name,
      figma_file_key: lib.figma_file_key,
      figma_file_name: lib.figma_file_name,
      prop_definitions: prop_definitions
    )

    component_id = "cs_#{cs.id}"
    sorted = variants.sort_by { |v| [v[:is_default] ? 0 : 1, 0] }

    sorted.each_with_index do |v, idx|
      func_name = "#{name}_#{component_id}__v#{idx}"
      compiled = "var #{func_name} = function(props) { return React.createElement('div', null, '#{v[:label]}'); }"

      cs.variants.create!(
        node_id: "test:#{SecureRandom.hex(4)}",
        name: v[:name],
        is_default: v[:is_default] || false,
        figma_json: v.fetch(:figma_json, { "id" => "test", "type" => "COMPONENT", "name" => v[:name], "children" => [] }),
        react_code_compiled: compiled
      )
    end

    cs.reload
  end

  describe "#try_load_per_variant" do
    let(:cs) do
      build_component_set_with_variants(
        library,
        name: "Page",
        prop_definitions: { "Type" => { "type" => "VARIANT", "defaultValue" => "Default" } },
        variants: [
          { name: "Type=Default", is_default: true, label: "default-page" },
          { name: "Type=Landing", is_default: false, label: "landing-page" }
        ]
      )
    end

    let(:variant_prop_names) { ["Type"] }
    let(:component_id) { "cs_#{cs.id}" }

    it "loads all variants when usages is empty (no-props usage)" do
      parts = []
      result = host.send(:try_load_per_variant, cs, "Page", variant_prop_names, [], parts)

      expect(result).to be true
      # Should have 3 parts: default variant code + landing variant code + dispatcher
      expect(parts.size).to eq(3)
      expect(parts.last).to include("var Page = function(")
      expect(parts.join("\n")).to include("Page_#{component_id}__v0")
      expect(parts.join("\n")).to include("Page_#{component_id}__v1")
    end

    it "loads all variants when usages is nil (DS preview)" do
      parts = []
      result = host.send(:try_load_per_variant, cs, "Page", variant_prop_names, nil, parts)

      expect(result).to be true
      expect(parts.size).to eq(3)
    end

    it "loads only matched variants when usages specify props" do
      parts = []
      usages = [{ "type" => "Landing" }]
      result = host.send(:try_load_per_variant, cs, "Page", variant_prop_names, usages, parts)

      expect(result).to be true
      # default + matched Landing + dispatcher
      all_code = parts.join("\n")
      expect(all_code).to include("Page_#{component_id}__v0") # default always included
      expect(all_code).to include("Page_#{component_id}__v1") # matched
    end

    it "generates a dispatcher that defines the component name" do
      parts = []
      host.send(:try_load_per_variant, cs, "Page", variant_prop_names, [], parts)

      dispatcher = parts.last
      expect(dispatcher).to start_with("var Page = function(")
      expect(dispatcher).to include("type === \"Landing\"")
      expect(dispatcher).to include("return Page_#{component_id}__v0(props);") # default fallback
    end

    it "returns false when no non-default variants have compiled code" do
      # Remove compiled code from non-default variants
      cs.variants.where(is_default: false).update_all(react_code_compiled: nil)

      parts = []
      result = host.send(:try_load_per_variant, cs, "Page", variant_prop_names, [], parts)

      expect(result).to be false
      expect(parts).to be_empty
    end

    context "with variant missing figma_json (index alignment)" do
      let(:cs_with_gap) do
        cs = library.component_sets.create!(
          node_id: "test:gap:#{SecureRandom.hex(4)}",
          name: "Card",
          figma_file_key: library.figma_file_key,
          figma_file_name: library.figma_file_name,
          prop_definitions: { "Size" => { "type" => "VARIANT", "defaultValue" => "M" } }
        )

        component_id = "cs_#{cs.id}"

        # Default variant (idx 0 in factory)
        cs.variants.create!(
          node_id: "test:gap:v0",
          name: "Size=M",
          is_default: true,
          figma_json: { "id" => "v0", "type" => "COMPONENT", "name" => "Size=M", "children" => [] },
          react_code_compiled: "var Card_#{component_id}__v0 = function(props) { return React.createElement('div', null, 'M'); }"
        )

        # Variant WITHOUT figma_json — factory skips this, doesn't get an index
        cs.variants.create!(
          node_id: "test:gap:v_no_json",
          name: "Size=S",
          is_default: false,
          figma_json: nil,
          react_code_compiled: nil
        )

        # Non-default variant (idx 1 in factory, because factory filters out no-json variant)
        cs.variants.create!(
          node_id: "test:gap:v1",
          name: "Size=L",
          is_default: false,
          figma_json: { "id" => "v1", "type" => "COMPONENT", "name" => "Size=L", "children" => [] },
          react_code_compiled: "var Card_#{component_id}__v1 = function(props) { return React.createElement('div', null, 'L'); }"
        )

        cs.reload
      end

      it "filters out variants without figma_json so indices match factory" do
        component_id = "cs_#{cs_with_gap.id}"
        parts = []
        host.send(:try_load_per_variant, cs_with_gap, "Card", ["Size"], [], parts)

        dispatcher = parts.last
        # Dispatcher should reference v0 and v1 (matching factory indices),
        # NOT v0 and v2 (which would happen without the figma_json filter)
        expect(dispatcher).to include("Card_#{component_id}__v0")
        expect(dispatcher).to include("Card_#{component_id}__v1")
        expect(dispatcher).not_to include("Card_#{component_id}__v2")
      end
    end
  end

  describe "#render_figma_files" do
    context "component set with per-variant code used without props" do
      let!(:cs) do
        build_component_set_with_variants(
          library,
          name: "Page",
          prop_definitions: { "Type" => { "type" => "VARIANT", "defaultValue" => "Default" } },
          variants: [
            { name: "Type=Default", is_default: true, label: "default" },
            { name: "Type=Landing", is_default: false, label: "landing" }
          ]
        )
      end

      it "defines the component as a global var in the rendered HTML" do
        jsx = "<Page />"
        used = host.send(:extract_component_names, jsx)
        usages = host.send(:extract_component_usages, jsx)

        html = host.send(:render_figma_files, [library], only: used, component_usages: usages)

        expect(html).to include("var Page = function(")
      end

      it "does not produce ReferenceError for component used without props" do
        jsx = "<Page />"
        used = host.send(:extract_component_names, jsx)
        usages = host.send(:extract_component_usages, jsx)

        html = host.send(:render_figma_files, [library], only: used, component_usages: usages)

        component_id = "cs_#{cs.id}"
        # The dispatcher must reference functions that are actually defined
        dispatcher_match = html.match(/var Page = function\([^)]*\) \{([^}]+)\}/)
        expect(dispatcher_match).not_to be_nil

        body = dispatcher_match[1]
        referenced_funcs = body.scan(/Page_cs_\d+__v\d+/).uniq
        referenced_funcs.each do |func|
          expect(html).to include("var #{func} = function"), "Expected #{func} to be defined but it wasn't"
        end
      end
    end
  end
end
