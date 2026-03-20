require "rails_helper"

RSpec.describe Figma::Importer do
  let(:user) { users(:alice) }

  describe "#import" do
    context "with example-lib (figma file with deps)" do
      let(:figma_response) { load_figma_fixture("example_lib") }

      it "imports component sets and standalone components" do
        ds = FigmaFile.create!(
          user: user,
          name: "Import Test Lib",
          figma_url: "https://www.figma.com/design/TESTLIB123/import-lib",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get)
          .with("/v1/files/TESTLIB123")
          .and_return(figma_response)

        expect { described_class.new(ds).import }.to change { ds.component_sets.count }.from(0)

        ds.reload

        # Should have 1 component set (Button)
        expect(ds.component_sets.count).to eq(1)
        button_set = ds.component_sets.find_by(name: "Button")
        expect(button_set).to be_present
        expect(button_set.node_id).to eq("1:100")
        expect(button_set.variants.count).to eq(2)

        # Default variant should be identified
        default_variant = button_set.variants.find_by(is_default: true)
        expect(default_variant).to be_present
        expect(default_variant.name).to eq("Size=M, State=default")

        # Should have 2 standalone components (Divider, Badge)
        # CardWithIcon is not in the fixture JSON — only Divider and Badge
        expect(ds.components.count).to eq(2)
        expect(ds.components.pluck(:name)).to contain_exactly("Divider", "Badge")

        # Figma file name should be set
        expect(ds.figma_file_name).to eq("example-lib")
      end

      it "preserves INSTANCE references in figma_json (no detaching)" do
        ds = FigmaFile.create!(
          user: user,
          name: "Preserve Instances",
          figma_url: "https://www.figma.com/design/TESTPRES123/preserve-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        button_set = ds.component_sets.find_by(name: "Button")
        default_variant = button_set.variants.find_by(is_default: true)
        json = default_variant.figma_json

        # The INSTANCE node referencing IconArrow should remain intact
        instance_node = find_node_by_type(json, "INSTANCE")
        expect(instance_node).to be_present
        expect(instance_node["componentId"]).to eq("2:101")
        expect(instance_node["name"]).to eq("IconArrow")
      end

      it "re-imports without duplicating records" do
        ds = FigmaFile.create!(
          user: user,
          name: "Re-import Test",
          figma_url: "https://www.figma.com/design/TESTREIMPORT/reimport-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        initial_sets = ds.component_sets.count
        initial_components = ds.components.count

        # Import again
        described_class.new(ds).import
        ds.reload

        expect(ds.component_sets.count).to eq(initial_sets)
        expect(ds.components.count).to eq(initial_components)
      end

      it "cleans up removed components on re-import" do
        ds = FigmaFile.create!(
          user: user,
          name: "Cleanup Test",
          figma_url: "https://www.figma.com/design/TESTCLEANUP/cleanup-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        # Manually add an extra component that shouldn't exist
        ds.components.create!(node_id: "99:999", name: "Ghost", figma_json: {})

        # Re-import — ghost should be removed
        described_class.new(ds).import
        ds.reload

        expect(ds.components.find_by(name: "Ghost")).to be_nil
      end
    end

    context "with example-icons (icon library)" do
      let(:figma_response) { load_figma_fixture("example_icons") }

      it "imports icon component sets with vector-only content" do
        ds = FigmaFile.create!(
          user: user,
          name: "Icon Import Test",
          figma_url: "https://www.figma.com/design/TESTICONS123/icon-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        # Should have 2 component sets (IconArrow, IconClose)
        expect(ds.component_sets.count).to eq(2)
        expect(ds.component_sets.pluck(:name)).to contain_exactly("IconArrow", "IconClose")

        # No standalone components in icon library
        expect(ds.components.count).to eq(0)

        # All vector sets should be detected as vectors
        ds.component_sets.each do |cs|
          expect(cs).to be_vector, "Expected #{cs.name} to be a vector"
        end

        # File name should be set
        expect(ds.figma_file_name).to eq("example-icons")
      end
    end

    context "when componentPropertyDefinitions has Figma #nodeId suffixes" do
      it "strips #nodeId suffixes from prop_definition keys" do
        figma_response = {
          "name" => "suffix-test",
          "componentSets" => {
            "1:100" => { "name" => "Card", "description" => "" }
          },
          "components" => {
            "1:101" => { "name" => "Size=M", "componentSetId" => "1:100", "description" => "" }
          },
          "styles" => {},
          "document" => {
            "children" => [{
              "id" => "0:1",
              "name" => "Page 1",
              "type" => "CANVAS",
              "children" => [{
                "id" => "1:100",
                "name" => "Card",
                "type" => "COMPONENT_SET",
                "componentPropertyDefinitions" => {
                  "Size"           => { "type" => "VARIANT", "defaultValue" => "M", "variantOptions" => ["M", "L"] },
                  "Content#2:1405" => { "type" => "TEXT", "defaultValue" => "Click me" },
                  "Disabled#3:201" => { "type" => "BOOLEAN", "defaultValue" => false }
                },
                "children" => [{
                  "id" => "1:101",
                  "name" => "Size=M",
                  "type" => "COMPONENT",
                  "children" => [{
                    "id" => "1:102", "name" => "bg", "type" => "RECTANGLE",
                    "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 1 } }],
                    "strokes" => []
                  }]
                }]
              }]
            }]
          }
        }

        ds = FigmaFile.create!(
          user: user,
          name: "Suffix Strip Test",
          figma_url: "https://www.figma.com/design/TESTSUFFIX/suffix-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        card_set = ds.component_sets.find_by(name: "Card")
        expect(card_set).to be_present
        expect(card_set.prop_definitions.keys).to contain_exactly("Size", "Content", "Disabled")
        expect(card_set.prop_definitions["Content"]).to eq({ "type" => "TEXT", "defaultValue" => "Click me" })
        expect(card_set.prop_definitions["Disabled"]).to eq({ "type" => "BOOLEAN", "defaultValue" => false })
        expect(card_set.prop_definitions.keys).not_to include(match(/#/))
      end
    end

    context "with INSTANCE_SWAP preferredValues" do
      it "populates slots from preferredValues component keys" do
        figma_response = {
          "name" => "slot-test",
          "componentSets" => {
            "1:100" => { "name" => "Page", "description" => "", "key" => "page-key-abc" },
            "2:100" => { "name" => "Title", "description" => "", "key" => "title-key-xyz" },
            "3:100" => { "name" => "Button", "description" => "", "key" => "button-key-def" }
          },
          "components" => {
            "1:101" => { "name" => "Default", "componentSetId" => "1:100", "description" => "" },
            "2:101" => { "name" => "Default", "componentSetId" => "2:100", "description" => "" },
            "3:101" => { "name" => "Default", "componentSetId" => "3:100", "description" => "" }
          },
          "styles" => {},
          "document" => {
            "children" => [{
              "id" => "0:1",
              "name" => "Page 1",
              "type" => "CANVAS",
              "children" => [
                {
                  "id" => "1:100",
                  "name" => "Page",
                  "type" => "COMPONENT_SET",
                  "description" => "",
                  "componentPropertyDefinitions" => {
                    "Content" => {
                      "type" => "INSTANCE_SWAP",
                      "defaultValue" => "2:101",
                      "preferredValues" => [
                        { "type" => "COMPONENT_SET", "key" => "title-key-xyz" },
                        { "type" => "COMPONENT_SET", "key" => "button-key-def" }
                      ]
                    }
                  },
                  "children" => [{
                    "id" => "1:101",
                    "name" => "Default",
                    "type" => "COMPONENT",
                    "children" => [{
                      "id" => "1:102",
                      "type" => "INSTANCE",
                      "name" => "content placeholder",
                      "componentId" => "2:101",
                      "componentPropertyReferences" => { "mainComponent" => "Content" }
                    }]
                  }]
                },
                {
                  "id" => "2:100",
                  "name" => "Title",
                  "type" => "COMPONENT_SET",
                  "description" => "",
                  "componentPropertyDefinitions" => {},
                  "children" => [{
                    "id" => "2:101",
                    "name" => "Default",
                    "type" => "COMPONENT",
                    "children" => [{ "id" => "2:102", "type" => "TEXT", "name" => "text", "characters" => "Title" }]
                  }]
                },
                {
                  "id" => "3:100",
                  "name" => "Button",
                  "type" => "COMPONENT_SET",
                  "description" => "",
                  "componentPropertyDefinitions" => {},
                  "children" => [{
                    "id" => "3:101",
                    "name" => "Default",
                    "type" => "COMPONENT",
                    "children" => [{ "id" => "3:102", "type" => "TEXT", "name" => "label", "characters" => "Click" }]
                  }]
                }
              ]
            }]
          }
        }

        ds = FigmaFile.create!(
          user: user,
          name: "PreferredValues Test",
          figma_url: "https://www.figma.com/design/TESTPV123/pv-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        page_set = ds.component_sets.find_by(name: "Page")
        expect(page_set).to be_present
        expect(page_set.slots).to eq([{ "name" => "Content", "allowed_children" => ["Title", "Button"] }])
      end
    end

    context "with #root in name or description" do
      it "sets is_root true when name contains #root" do
        figma_response = {
          "name" => "root-test",
          "componentSets" => {
            "1:100" => { "name" => "App #root", "description" => "", "key" => "app-key" }
          },
          "components" => {
            "1:101" => { "name" => "Default", "componentSetId" => "1:100", "description" => "" }
          },
          "styles" => {},
          "document" => {
            "children" => [{
              "id" => "0:1", "name" => "Page 1", "type" => "CANVAS",
              "children" => [{
                "id" => "1:100",
                "name" => "App #root",
                "type" => "COMPONENT_SET",
                "description" => "",
                "componentPropertyDefinitions" => {},
                "children" => [{
                  "id" => "1:101", "name" => "Default", "type" => "COMPONENT",
                  "children" => [{ "id" => "1:102", "type" => "RECTANGLE", "name" => "bg",
                    "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 1, "b" => 1 } }], "strokes" => [] }]
                }]
              }]
            }]
          }
        }

        ds = FigmaFile.create!(
          user: user,
          name: "Root Name Test",
          figma_url: "https://www.figma.com/design/TESTROOT1/root-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        app_set = ds.component_sets.find_by(name: "App #root")
        expect(app_set).to be_present
        expect(app_set.is_root).to be true
      end

      it "sets is_root true when description contains #root" do
        figma_response = {
          "name" => "root-desc-test",
          "componentSets" => {
            "1:100" => { "name" => "Layout", "description" => "Main layout component #root", "key" => "layout-key" }
          },
          "components" => {
            "1:101" => { "name" => "Default", "componentSetId" => "1:100", "description" => "" }
          },
          "styles" => {},
          "document" => {
            "children" => [{
              "id" => "0:1", "name" => "Page 1", "type" => "CANVAS",
              "children" => [{
                "id" => "1:100",
                "name" => "Layout",
                "type" => "COMPONENT_SET",
                "description" => "Main layout component #root",
                "componentPropertyDefinitions" => {},
                "children" => [{
                  "id" => "1:101", "name" => "Default", "type" => "COMPONENT",
                  "children" => [{ "id" => "1:102", "type" => "RECTANGLE", "name" => "bg",
                    "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 1, "b" => 1 } }], "strokes" => [] }]
                }]
              }]
            }]
          }
        }

        ds = FigmaFile.create!(
          user: user,
          name: "Root Desc Test",
          figma_url: "https://www.figma.com/design/TESTROOT2/root-desc-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        layout_set = ds.component_sets.find_by(name: "Layout")
        expect(layout_set).to be_present
        expect(layout_set.is_root).to be true
      end

      it "leaves is_root false when neither name nor description contains #root" do
        figma_response = {
          "name" => "no-root-test",
          "componentSets" => {
            "1:100" => { "name" => "Card", "description" => "A card component", "key" => "card-key" }
          },
          "components" => {
            "1:101" => { "name" => "Default", "componentSetId" => "1:100", "description" => "" }
          },
          "styles" => {},
          "document" => {
            "children" => [{
              "id" => "0:1", "name" => "Page 1", "type" => "CANVAS",
              "children" => [{
                "id" => "1:100",
                "name" => "Card",
                "type" => "COMPONENT_SET",
                "description" => "A card component",
                "componentPropertyDefinitions" => {},
                "children" => [{
                  "id" => "1:101", "name" => "Default", "type" => "COMPONENT",
                  "children" => [{ "id" => "1:102", "type" => "RECTANGLE", "name" => "bg",
                    "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 1, "b" => 1 } }], "strokes" => [] }]
                }]
              }]
            }]
          }
        }

        ds = FigmaFile.create!(
          user: user,
          name: "No Root Test",
          figma_url: "https://www.figma.com/design/TESTNOROOT/no-root-test",
          status: "importing"
        )

        mock_client = instance_double(Figma::Client)
        allow(Figma::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get).and_return(figma_response)

        described_class.new(ds).import
        ds.reload

        card_set = ds.component_sets.find_by(name: "Card")
        expect(card_set).to be_present
        expect(card_set.is_root).to be false
      end
    end

    context "with no file key" do
      it "skips import" do
        ds = FigmaFile.new(id: 0, figma_file_key: nil)
        allow(ds).to receive(:update!)

        # Should not raise — just log and skip
        expect { described_class.new(ds).import }.not_to raise_error
      end
    end
  end

  private

  def find_node_by_type(node, type)
    return nil unless node.is_a?(Hash)
    return node if node["type"] == type

    (node["children"] || []).each do |child|
      found = find_node_by_type(child, type)
      return found if found
    end

    nil
  end
end
