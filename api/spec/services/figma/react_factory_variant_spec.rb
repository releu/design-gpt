require "rails_helper"

RSpec.describe Figma::ReactFactory, "multi-variant dispatch" do
  fixtures :figma_files, :component_sets, :component_variants

  let(:library) { figma_files(:example_lib) }
  let(:factory) { described_class.new(library) }

  describe "component set with multiple VARIANT props and variants" do
    let(:multi_variant_set) do
      cs = library.component_sets.create!(
        node_id: "mv:100",
        name: "Button",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Size" => { "type" => "VARIANT", "defaultValue" => "M" },
          "State" => { "type" => "VARIANT", "defaultValue" => "default" }
        }
      )
      cs.variants.create!(
        node_id: "mv:101",
        name: "Size=M, State=default",
        is_default: true,
        figma_json: {
          "id" => "mv:101",
          "type" => "COMPONENT",
          "name" => "Size=M, State=default",
          "children" => [
            { "id" => "mv:110", "type" => "TEXT", "name" => "label", "characters" => "Click me", "visible" => true }
          ]
        }
      )
      cs.variants.create!(
        node_id: "mv:102",
        name: "Size=M, State=hover",
        is_default: false,
        figma_json: {
          "id" => "mv:102",
          "type" => "COMPONENT",
          "name" => "Size=M, State=hover",
          "children" => [
            { "id" => "mv:120", "type" => "TEXT", "name" => "label", "characters" => "Hover me", "visible" => true }
          ]
        }
      )
      cs
    end

    it "generates internal variant functions" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      expect(code).to include("function Button__v0(")
      expect(code).to include("function Button__v1(")
    end

    it "generates a dispatcher function with VARIANT prop matching" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      expect(code).to include("export function Button(")
      expect(code).to match(/size === "M"/)
      expect(code).to match(/state === "default"/)
      expect(code).to match(/state === "hover"/)
    end

    it "generates a combined const styles" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      # Should have exactly one const styles declaration
      expect(code.scan("const styles = `").size).to eq(1)
    end

    it "injects styles only in the dispatcher, not in variant functions" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      # Variant functions should NOT contain <style>
      variant_funcs = code.scan(/function Button__v\d+\([^)]*\) \{.*?\n\}/m)
      variant_funcs.each do |func|
        expect(func).not_to include("<style>")
      end

      # Dispatcher should contain <style>
      dispatcher = code[/export function Button\(.*?\n\}/m]
      expect(dispatcher).to include("<style>{styles}</style>")
    end

    it "passes ...props to variant functions" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      expect(code).to include("<Button__v0 {...props} />")
      expect(code).to include("<Button__v1 {...props} />")
    end

    it "includes a fallback return for the default variant" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      # Last return should be the fallback (default variant, whichever index it got)
      lines = code.lines.select { |l| l.strip.start_with?("return") }
      expect(lines.last).to match(/Button__v\d+/)
    end

    it "has per-variant scoped CSS classes" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      expect(code).to include("buttonv0-")
      expect(code).to include("buttonv1-")
    end

    it "adds variant BEM classes to each variant's root element" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      # variant 0: Size=M, State=default
      expect(code).to include("Button__size_m")
      expect(code).to include("Button__state_default")

      # variant 1: Size=M, State=hover
      expect(code).to include("Button__state_hover")
    end

    it "includes variant BEM classes alongside the scoped root class" do
      result = factory.generate_component_set(multi_variant_set)
      code = result[:code]

      # Root element must carry both the scoped class and the variant classes
      expect(code).to match(/className="buttonv0-root Button__size_m Button__state_default"/)
      expect(code).to match(/className="buttonv1-root Button__size_m Button__state_hover"/)
    end
  end

  describe "single-variant component set with VARIANT prop" do
    let(:single_variant_set) do
      cs = library.component_sets.create!(
        node_id: "sv:100",
        name: "Badge",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Color" => { "type" => "VARIANT", "defaultValue" => "red" }
        }
      )
      cs.variants.create!(
        node_id: "sv:101",
        name: "Color=red",
        is_default: true,
        figma_json: {
          "id" => "sv:101",
          "type" => "COMPONENT",
          "name" => "Color=red",
          "children" => [
            { "id" => "sv:110", "type" => "TEXT", "name" => "label", "characters" => "New", "visible" => true }
          ]
        }
      )
      cs
    end

    it "falls back to single-function code (no dispatcher)" do
      result = factory.generate_component_set(single_variant_set)
      code = result[:code]

      expect(code).to include("export function Badge(")
      expect(code).not_to include("Badge__v0")
      expect(code).not_to include("Badge__v1")
    end
  end

  describe "component with TEXT + VARIANT props" do
    let(:text_variant_set) do
      cs = library.component_sets.create!(
        node_id: "tv:100",
        name: "Tag",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Size" => { "type" => "VARIANT", "defaultValue" => "S" },
          "label" => { "type" => "TEXT", "defaultValue" => "Tag" }
        }
      )
      cs.variants.create!(
        node_id: "tv:101",
        name: "Size=S",
        is_default: true,
        figma_json: {
          "id" => "tv:101",
          "type" => "COMPONENT",
          "name" => "Size=S",
          "children" => [
            {
              "id" => "tv:110", "type" => "TEXT", "name" => "label", "characters" => "Tag", "visible" => true,
              "componentPropertyReferences" => { "characters" => "label" }
            }
          ]
        }
      )
      cs.variants.create!(
        node_id: "tv:102",
        name: "Size=L",
        is_default: false,
        figma_json: {
          "id" => "tv:102",
          "type" => "COMPONENT",
          "name" => "Size=L",
          "children" => [
            {
              "id" => "tv:120", "type" => "TEXT", "name" => "label", "characters" => "Tag", "visible" => true,
              "componentPropertyReferences" => { "characters" => "label" }
            }
          ]
        }
      )
      cs
    end

    it "puts TEXT props in variant function destructuring" do
      result = factory.generate_component_set(text_variant_set)
      code = result[:code]

      # Variant functions should destructure TEXT props
      expect(code).to match(/function Tag__v0\(\{.*label.*\}\)/)
    end

    it "puts VARIANT props in dispatcher destructuring" do
      result = factory.generate_component_set(text_variant_set)
      code = result[:code]

      expect(code).to match(/export function Tag\(\{.*size = "S".*\}\)/)
    end

    it "renders text prop as expression in variant functions" do
      result = factory.generate_component_set(text_variant_set)
      code = result[:code]

      expect(code).to include("{label}")
    end
  end

  describe "compiled output" do
    let(:multi_variant_set) do
      cs = library.component_sets.create!(
        node_id: "comp:100",
        name: "Chip",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "State" => { "type" => "VARIANT", "defaultValue" => "idle" }
        }
      )
      cs.variants.create!(
        node_id: "comp:101",
        name: "State=idle",
        is_default: true,
        figma_json: {
          "id" => "comp:101",
          "type" => "COMPONENT",
          "name" => "State=idle",
          "children" => [
            { "id" => "comp:110", "type" => "TEXT", "name" => "text", "characters" => "Idle", "visible" => true }
          ]
        }
      )
      cs.variants.create!(
        node_id: "comp:102",
        name: "State=active",
        is_default: false,
        figma_json: {
          "id" => "comp:102",
          "type" => "COMPONENT",
          "name" => "State=active",
          "children" => [
            { "id" => "comp:120", "type" => "TEXT", "name" => "text", "characters" => "Active", "visible" => true }
          ]
        }
      )
      cs
    end

    it "namespaces internal variant functions with component_id" do
      result = factory.generate_component_set(multi_variant_set)
      compiled = result[:compiled_code]

      # Internal functions should be namespaced
      expect(compiled).to include("Chip_cs_#{multi_variant_set.id}__v0")
      expect(compiled).to include("Chip_cs_#{multi_variant_set.id}__v1")

      # Original un-namespaced names should NOT appear
      expect(compiled).not_to match(/\bChip__v0\b/)
      expect(compiled).not_to match(/\bChip__v1\b/)
    end

    it "namespaces the styles variable" do
      result = factory.generate_component_set(multi_variant_set)
      compiled = result[:compiled_code]

      expect(compiled).to include("styles_cs_#{multi_variant_set.id}")
    end
  end

  describe "component set with no VARIANT props" do
    let(:no_variant_props_set) do
      cs = library.component_sets.create!(
        node_id: "nv:100",
        name: "Divider",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {}
      )
      cs.variants.create!(
        node_id: "nv:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "nv:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => []
        }
      )
      cs.variants.create!(
        node_id: "nv:102",
        name: "Thick",
        is_default: false,
        figma_json: {
          "id" => "nv:102",
          "type" => "COMPONENT",
          "name" => "Thick",
          "children" => []
        }
      )
      cs
    end

    it "falls back to single-function code (no dispatcher)" do
      result = factory.generate_component_set(no_variant_props_set)
      code = result[:code]

      expect(code).to include("export function Divider(")
      expect(code).not_to include("Divider__v0")
    end
  end
end
