require "rails_helper"

RSpec.describe Figma::ReactFactory, "icon fill color override" do
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

  # Button component set with INSTANCE_SWAP for icon
  let(:button_with_icon) do
    cs = library.component_sets.create!(
      node_id: "btn:100",
      name: "ActionButton",
      figma_file_key: library.figma_file_key,
      figma_file_name: library.figma_file_name,
      prop_definitions: {
        "View" => { "type" => "VARIANT", "defaultValue" => "Action" },
        " ↳ Start icon#2:0" => { "type" => "INSTANCE_SWAP", "defaultValue" => "icon:101", "preferredValues" => [] }
      }
    )
    # Variant where icon fill is overridden to WHITE (on dark/action background)
    cs.variants.create!(
      node_id: "btn:101",
      name: "View=Action",
      is_default: true,
      figma_json: {
        "id" => "btn:101",
        "type" => "COMPONENT",
        "name" => "View=Action",
        "children" => [
          {
            "id" => "btn:110",
            "name" => "icon left",
            "type" => "INSTANCE",
            "componentId" => "icon:101",
            "componentPropertyReferences" => { "mainComponent" => " ↳ Start icon#2:0" },
            "overrides" => [
              { "id" => "btn:110", "overriddenFields" => ["fills"] }
            ],
            "children" => [
              {
                "id" => "I-btn:110;icon:102",
                "name" => "icon",
                "type" => "VECTOR",
                "fills" => [
                  { "type" => "SOLID", "color" => { "r" => 1.0, "g" => 1.0, "b" => 1.0, "a" => 1.0 }, "blendMode" => "NORMAL" }
                ]
              }
            ]
          }
        ]
      }
    )
    cs
  end

  it "passes icon fill color when instance overrides fill to non-black" do
    result = factory.generate_component_set(button_with_icon)
    code = result[:code]

    # The INSTANCE_SWAP icon should receive a color prop with the overridden fill
    expect(code).to include("StartIconComponent")
    expect(code).to match(/StartIconComponent.*color.*["']#ffffff["']/i)
  end

  # Variant where icon fill is NOT overridden (default black) — no color prop needed
  let(:button_with_default_icon) do
    cs = library.component_sets.create!(
      node_id: "btn2:100",
      name: "DefaultButton",
      figma_file_key: library.figma_file_key,
      figma_file_name: library.figma_file_name,
      prop_definitions: {
        " ↳ Start icon#3:0" => { "type" => "INSTANCE_SWAP", "defaultValue" => "icon:101", "preferredValues" => [] }
      }
    )
    cs.variants.create!(
      node_id: "btn2:101",
      name: "Default",
      is_default: true,
      figma_json: {
        "id" => "btn2:101",
        "type" => "COMPONENT",
        "name" => "Default",
        "children" => [
          {
            "id" => "btn2:110",
            "name" => "icon left",
            "type" => "INSTANCE",
            "componentId" => "icon:101",
            "componentPropertyReferences" => { "mainComponent" => " ↳ Start icon#3:0" },
            "children" => [
              {
                "id" => "I-btn2:110;icon:102",
                "name" => "icon",
                "type" => "VECTOR",
                "fills" => [
                  { "type" => "SOLID", "color" => { "r" => 0.0, "g" => 0.0, "b" => 0.0, "a" => 1.0 } }
                ]
              }
            ]
          }
        ]
      }
    )
    cs
  end

  it "does not pass color prop when icon fill is default black" do
    result = factory.generate_component_set(button_with_default_icon)
    code = result[:code]

    expect(code).to include("StartIconComponent")
    expect(code).not_to match(/color=/)
  end
end
