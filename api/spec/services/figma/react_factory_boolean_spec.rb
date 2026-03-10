require "rails_helper"

RSpec.describe Figma::ReactFactory, "boolean prop visibility" do
  fixtures :figma_files, :component_sets, :component_variants

  let(:library) { figma_files(:example_lib) }
  let(:factory) { described_class.new(library) }

  describe "boolean prop controlling element visibility" do
    let(:component_set) do
      cs = library.component_sets.create!(
        node_id: "bool:100",
        name: "Title",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "marker" => { "type" => "BOOLEAN", "defaultValue" => false },
          "title"  => { "type" => "TEXT", "defaultValue" => "title" }
        }
      )
      cs.variants.create!(
        node_id: "bool:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "bool:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "bool:110",
              "type" => "RECTANGLE",
              "name" => "Rectangle 2",
              "visible" => false,
              "componentPropertyReferences" => { "visible" => "marker" },
              "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 } }]
            },
            {
              "id" => "bool:111",
              "type" => "TEXT",
              "name" => "label",
              "characters" => "title",
              "visible" => true,
              "componentPropertyReferences" => { "characters" => "title" }
            }
          ]
        }
      )
      cs
    end

    it "includes boolean-controlled element wrapped in conditional even when visible is false" do
      result = factory.generate_component_set(component_set)
      code = result[:code]

      expect(code).to include("{marker && (")
      expect(code).to include("title-rectangle-2")
    end

    it "does not skip the element entirely" do
      result = factory.generate_component_set(component_set)
      code = result[:code]

      # The Rectangle 2 div should be present in the output
      expect(code).to match(/div.*className.*rectangle/)
    end
  end
end
