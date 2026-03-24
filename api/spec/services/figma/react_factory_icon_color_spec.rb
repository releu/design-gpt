require "rails_helper"

RSpec.describe Figma::ReactFactory, "INSTANCE_SWAP style overrides" do
  fixtures :figma_files, :component_sets, :component_variants

  let(:library) { figma_files(:example_lib) }
  let(:factory) { described_class.new(library) }

  # Icon component set (vector icon, resolved via INSTANCE_SWAP)
  let!(:icon_set) do
    cs = library.component_sets.create!(
      node_id: "icon:100",
      name: "PencilToLine",
      figma_file_key: library.figma_file_key,
      figma_file_name: library.figma_file_name,
      prop_definitions: {}
    )
    cs.variants.create!(
      node_id: "icon:101",
      name: "Default",
      is_default: true,
      figma_json: {
        "id" => "icon:101",
        "type" => "COMPONENT",
        "name" => "Default",
        "children" => [
          {
            "id" => "icon:102",
            "type" => "VECTOR",
            "name" => "icon",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }]
          }
        ]
      }
    )
    cs
  end

  def make_button(node_prefix:, name:, prop_key:, instance_children:, instance_bbox: nil)
    cs = library.component_sets.create!(
      node_id: "#{node_prefix}:100",
      name: name,
      figma_file_key: library.figma_file_key,
      figma_file_name: library.figma_file_name,
      prop_definitions: {
        prop_key => { "type" => "INSTANCE_SWAP", "defaultValue" => "icon:101", "preferredValues" => [] }
      }
    )
    instance_node = {
      "id" => "#{node_prefix}:110",
      "name" => "icon left",
      "type" => "INSTANCE",
      "componentId" => "icon:101",
      "componentPropertyReferences" => { "mainComponent" => prop_key },
      "children" => instance_children
    }
    instance_node["absoluteBoundingBox"] = instance_bbox if instance_bbox
    cs.variants.create!(
      node_id: "#{node_prefix}:101",
      name: "Default",
      is_default: true,
      figma_json: {
        "id" => "#{node_prefix}:101",
        "type" => "COMPONENT",
        "name" => "Default",
        "children" => [instance_node]
      }
    )
    cs
  end

  describe "fill color override" do
    it "passes color style when instance overrides fill to non-black" do
      cs = make_button(
        node_prefix: "btn1", name: "ActionButton", prop_key: " ↳ Start icon#2:0",
        instance_children: [
          { "id" => "I:102", "type" => "VECTOR", "name" => "icon",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 1.0, "g" => 1.0, "b" => 1.0, "a" => 1.0 } }] }
        ]
      )
      code = factory.generate_component_set(cs)[:code]

      expect(code).to include("StartIconComponent")
      expect(code).to match(/style=.*color.*#ffffff/i)
    end

    it "does not pass color when fill is default black" do
      cs = make_button(
        node_prefix: "btn2", name: "DefaultButton", prop_key: " ↳ Start icon#3:0",
        instance_children: [
          { "id" => "I:202", "type" => "VECTOR", "name" => "icon",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.0, "g" => 0.0, "b" => 0.0, "a" => 1.0 } }] }
        ]
      )
      code = factory.generate_component_set(cs)[:code]

      expect(code).to include("StartIconComponent")
      expect(code).not_to match(/color:/)
    end
  end

  describe "size override" do
    it "passes width and height from instance bounding box" do
      cs = make_button(
        node_prefix: "btn3", name: "SmallButton", prop_key: " ↳ Start icon#4:0",
        instance_children: [
          { "id" => "I:302", "type" => "VECTOR", "name" => "icon",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.0, "g" => 0.0, "b" => 0.0, "a" => 1.0 } }] }
        ],
        instance_bbox: { "x" => 0, "y" => 0, "width" => 12.0, "height" => 12.0 }
      )
      code = factory.generate_component_set(cs)[:code]

      expect(code).to match(/style=.*width.*12px/)
      expect(code).to match(/style=.*height.*12px/)
    end
  end

  describe "combined overrides" do
    it "passes both color and size when both are overridden" do
      cs = make_button(
        node_prefix: "btn4", name: "LargeActionButton", prop_key: " ↳ Start icon#5:0",
        instance_children: [
          { "id" => "I:402", "type" => "VECTOR", "name" => "icon",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 1.0, "g" => 1.0, "b" => 1.0, "a" => 1.0 } }] }
        ],
        instance_bbox: { "x" => 0, "y" => 0, "width" => 24.0, "height" => 24.0 }
      )
      code = factory.generate_component_set(cs)[:code]

      expect(code).to match(/style=.*color.*#ffffff/i)
      expect(code).to match(/style=.*width.*24px/)
      expect(code).to match(/style=.*height.*24px/)
    end
  end
end
