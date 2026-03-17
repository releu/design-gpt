require "rails_helper"

RSpec.describe Figma::ReactFactory, "image components" do
  fixtures :figma_files

  let(:library) { figma_files(:example_lib) }
  let(:factory) { described_class.new(library) }

  describe "is_image component (standalone)" do
    let(:image_component_set) do
      cs = library.component_sets.create!(
        node_id: "img:100",
        name: "Photo #image",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        is_image: true,
        prop_definitions: {}
      )
      cs.variants.create!(
        node_id: "img:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "img:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => []
        }
      )
      cs
    end

    it "generates a <div> with backgroundSize: 'cover'" do
      result = factory.generate_component_set(image_component_set)
      code = result[:code]

      expect(code).to include("<div")
      expect(code).to include("backgroundSize: 'cover'")
      expect(code).to include("backgroundImage")
      expect(code).to include("backgroundPosition: 'center'")
      expect(code).not_to include("<img")
    end
  end

  describe "INSTANCE_SWAP pointing to #image component" do
    let(:image_cs) do
      cs = library.component_sets.create!(
        node_id: "imgcs:100",
        name: "CoverImage #image",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        is_image: true,
        component_key: "imagekey123",
        prop_definitions: {}
      )
      cs.variants.create!(
        node_id: "imgcs:101",
        name: "Default",
        is_default: true,
        component_key: "imagevarkey123",
        figma_json: {
          "id" => "imgcs:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => []
        }
      )
      cs
    end

    let(:card_with_image_swap) do
      # Ensure image component exists first
      image_cs

      cs = library.component_sets.create!(
        node_id: "crdimg:100",
        name: "CardWithImage",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Cover" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "imgcs:101",
            "preferredValues" => [
              { "type" => "COMPONENT_SET", "key" => "imagekey123" }
            ]
          }
        }
      )
      cs.variants.create!(
        node_id: "crdimg:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "crdimg:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "crdimg:110",
              "type" => "TEXT",
              "name" => "title",
              "characters" => "Card Title",
              "visible" => true
            },
            {
              "id" => "crdimg:111",
              "type" => "INSTANCE",
              "name" => "cover placeholder",
              "componentId" => "imgcs:101",
              "visible" => true,
              "componentPropertyReferences" => { "mainComponent" => "Cover" }
            }
          ]
        }
      )
      cs
    end

    it "renders a <div> with background-image instead of <img>" do
      result = factory.generate_component_set(card_with_image_swap)
      code = result[:code]

      expect(code).to include("<div")
      expect(code).to include("backgroundSize: 'cover'")
      expect(code).to include("backgroundImage")
      expect(code).to include("backgroundPosition: 'center'")
      expect(code).not_to include("<img")
    end

    it "detects the node as an image_swap_instance" do
      # Verify the detection works by checking the generated code uses prop interpolation
      result = factory.generate_component_set(card_with_image_swap)
      code = result[:code]

      expect(code).to include("props.cover")
      expect(code).to include("encodeURIComponent")
    end
  end
end
