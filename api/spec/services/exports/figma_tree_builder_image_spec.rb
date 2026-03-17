require "rails_helper"

RSpec.describe Exports::FigmaTreeBuilder, "image components" do
  fixtures :users, :design_systems, :figma_files, :designs

  let(:design) { designs(:alice_design) }
  let(:ds) { design.design_system }
  let(:ff) { ds.current_figma_files.first || ds.figma_files.first }

  describe "isImage flag" do
    before do
      ff.component_sets.create!(
        node_id: "imgbuilder:100",
        name: "Photo #image",
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,
        is_image: true,
        prop_definitions: {}
      )
    end

    it "sets isImage: true on image component tree nodes" do
      tree = { "component" => "PhotoImage" }
      builder = described_class.new(design)
      result = builder.build(tree)

      expect(result["isImage"]).to eq(true)
    end

    it "does not set isImage on non-image components" do
      ff.component_sets.create!(
        node_id: "noimg:100",
        name: "Button",
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,
        is_image: false,
        prop_definitions: {}
      )

      tree = { "component" => "Button" }
      builder = described_class.new(design)
      result = builder.build(tree)

      expect(result["isImage"]).to be_nil
    end
  end

  describe "image INSTANCE_SWAP as textProperties" do
    before do
      image_cs = ff.component_sets.create!(
        node_id: "imgswapb:100",
        name: "CoverImg #image",
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,
        is_image: true,
        component_key: "imgswapkey",
        prop_definitions: {}
      )
      image_cs.variants.create!(
        node_id: "imgswapb:101",
        name: "Default",
        is_default: true,
        component_key: "imgswapvarkey",
        figma_json: { "id" => "imgswapb:101", "type" => "COMPONENT", "name" => "Default", "children" => [] }
      )

      ff.component_sets.create!(
        node_id: "cardb:100",
        name: "Article Card",
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,
        prop_definitions: {
          "Cover" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "imgswapb:101",
            "preferredValues" => [
              { "type" => "COMPONENT_SET", "key" => "imgswapkey" }
            ]
          },
          "Title" => { "type" => "TEXT", "defaultValue" => "Hello" }
        }
      )
    end

    it "includes image INSTANCE_SWAP prop in textProperties" do
      tree = { "component" => "ArticleCard", "cover" => "sunset beach", "title" => "My Article" }
      builder = described_class.new(design)
      result = builder.build(tree)

      expect(result["textProperties"]).to include("Cover" => "sunset beach")
      expect(result["textProperties"]).to include("Title" => "My Article")
    end
  end
end
