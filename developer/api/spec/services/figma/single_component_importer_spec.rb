require "rails_helper"

RSpec.describe Figma::SingleComponentImporter do
  let(:component_library) { component_libraries(:example_lib) }
  let(:importer) { described_class.new(component_library) }
  let(:mock_client) { instance_double(Figma::Client) }

  before do
    allow(Figma::Client).to receive(:new).and_return(mock_client)
  end

  describe "#reimport_component" do
    let(:component) { components(:divider) }

    it "fetches the node from Figma and updates the component" do
      node_response = {
        "nodes" => {
          component.node_id => {
            "document" => {
              "id" => component.node_id,
              "type" => "COMPONENT",
              "name" => "Divider",
              "componentPropertyDefinitions" => {},
              "children" => [
                { "id" => "1:201", "type" => "RECTANGLE", "name" => "line",
                  "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.9, "g" => 0.9, "b" => 0.9, "a" => 1 } }] }
              ]
            }
          }
        }
      }

      allow(mock_client).to receive(:get).and_return(node_response)
      allow_any_instance_of(Figma::AssetExtractor).to receive(:extract_for_component)
      allow_any_instance_of(Figma::ReactFactory).to receive(:generate_component)

      importer.reimport_component(component)

      component.reload
      expect(component.status).to eq("imported")
      expect(component.figma_json["children"].first["fills"].first["color"]["r"]).to eq(0.9)
    end

    it "sets status to error on failure" do
      allow(mock_client).to receive(:get).and_raise(StandardError, "API error")

      expect {
        importer.reimport_component(component)
      }.to raise_error(StandardError, "API error")

      component.reload
      expect(component.status).to eq("error")
      expect(component.error_message).to eq("API error")
    end
  end

  describe "#reimport_component_set" do
    let(:component_set) { component_sets(:button_set) }

    it "fetches the node from Figma and updates the component set and its variants" do
      node_response = {
        "nodes" => {
          component_set.node_id => {
            "document" => {
              "id" => component_set.node_id,
              "type" => "COMPONENT_SET",
              "name" => "Button",
              "componentPropertyDefinitions" => {
                "Size" => { "type" => "VARIANT", "defaultValue" => "L" }
              },
              "children" => component_set.variants.map { |v|
                { "id" => v.node_id, "type" => "COMPONENT", "name" => v.name, "children" => [] }
              }
            }
          }
        }
      }

      allow(mock_client).to receive(:get).and_return(node_response)
      allow_any_instance_of(Figma::ReactFactory).to receive(:generate_component_set)

      importer.reimport_component_set(component_set)

      component_set.reload
      expect(component_set.prop_definitions["Size"]["defaultValue"]).to eq("L")
    end
  end
end
