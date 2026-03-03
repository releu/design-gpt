require "rails_helper"

RSpec.describe Figma::ReactFactory, "slot convention" do
  fixtures :component_libraries, :component_sets, :component_variants

  let(:library) { component_libraries(:example_lib) }
  let(:factory) { described_class.new(library) }

  # Component set with no slot — standard behavior
  let(:normal_component_set) do
    cs = library.component_sets.create!(
      node_id: "normal:100",
      name: "Card",
      figma_file_key: library.figma_file_key,
      figma_file_name: library.figma_file_name,
      prop_definitions: {}
    )
    cs.variants.create!(
      node_id: "normal:101",
      name: "Default",
      is_default: true,
      figma_json: {
        "id" => "normal:101",
        "type" => "COMPONENT",
        "name" => "Default",
        "children" => [
          {
            "id" => "normal:110",
            "type" => "TEXT",
            "name" => "title",
            "characters" => "Hello",
            "visible" => true
          }
        ]
      }
    )
    cs
  end

  describe "component with Figma TEXT property (componentPropertyReferences)" do
    let(:text_prop_component_set) do
      cs = library.component_sets.create!(
        node_id: "textprop:100",
        name: "Title",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "title" => { "type" => "TEXT", "defaultValue" => "Hello World" }
        }
      )
      cs.variants.create!(
        node_id: "textprop:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "textprop:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "textprop:110",
              "type" => "TEXT",
              "name" => "label",
              "characters" => "Hello World",
              "visible" => true,
              "componentPropertyReferences" => { "characters" => "title" }
            }
          ]
        }
      )
      cs
    end

    it "renders the text node as a prop expression instead of static text" do
      result = factory.generate_component_set(text_prop_component_set)
      code = result[:code]

      expect(code).to include("{title}")
      expect(code).not_to match(/<span[^>]*>Hello World<\/span>/)
    end

    it "does not append {props.children}" do
      result = factory.generate_component_set(text_prop_component_set)
      code = result[:code]

      expect(code).not_to include("{props.children}")
    end
  end

  describe "TEXT property with Figma #nodeId suffix in componentPropertyReferences" do
    let(:suffixed_text_prop_set) do
      # Simulates real Figma import: prop_definitions keys have suffixes stripped,
      # but figma_json componentPropertyReferences still use the original suffixed keys.
      cs = library.component_sets.create!(
        node_id: "sfx:100",
        name: "Heading",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Content" => { "type" => "TEXT", "defaultValue" => "Hello" }
        }
      )
      cs.variants.create!(
        node_id: "sfx:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "sfx:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "sfx:110",
              "type" => "TEXT",
              "name" => "label",
              "characters" => "Hello",
              "visible" => true,
              "componentPropertyReferences" => { "characters" => "Content#2:1405" }
            }
          ]
        }
      )
      cs
    end

    it "resolves the suffixed reference to the stripped prop_definitions key" do
      result = factory.generate_component_set(suffixed_text_prop_set)
      code = result[:code]

      expect(code).to include("{content}")
      expect(code).not_to match(/<span[^>]*>Hello<\/span>/)
    end
  end

  describe "INSTANCE_SWAP slot with suffixed reference key" do
    let(:suffixed_slot_set) do
      cs = library.component_sets.create!(
        node_id: "sfxslot:100",
        name: "Container",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Content" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "title:001",
            "preferredValues" => [
              { "type" => "COMPONENT_SET", "key" => "abc123" }
            ]
          }
        }
      )
      cs.variants.create!(
        node_id: "sfxslot:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "sfxslot:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "sfxslot:110",
              "type" => "INSTANCE",
              "name" => "placeholder",
              "componentId" => "title:001",
              "visible" => true,
              "componentPropertyReferences" => { "mainComponent" => "Content#3:999" }
            }
          ]
        }
      )
      cs
    end

    it "detects the slot despite the suffixed reference" do
      result = factory.generate_component_set(suffixed_slot_set)
      code = result[:code]

      expect(code).to include("{props.children}")
    end
  end

  describe "component set without a slot" do
    it "does not include {props.children}" do
      result = factory.generate_component_set(normal_component_set)
      code = result[:code]

      expect(code).not_to include("{props.children}")
    end
  end

  describe "INSTANCE_SWAP + preferredValues slot" do
    let(:swap_slot_component_set) do
      cs = library.component_sets.create!(
        node_id: "swap:100",
        name: "Panel",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Content" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "title:001",
            "preferredValues" => [
              { "type" => "COMPONENT_SET", "key" => "abc123" },
              { "type" => "COMPONENT_SET", "key" => "def456" }
            ]
          }
        }
      )
      cs.variants.create!(
        node_id: "swap:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "swap:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "swap:110",
              "type" => "RECTANGLE",
              "name" => "background",
              "visible" => true
            },
            {
              "id" => "swap:111",
              "type" => "INSTANCE",
              "name" => "content placeholder",
              "componentId" => "title:001",
              "visible" => true,
              "componentPropertyReferences" => { "mainComponent" => "Content" }
            }
          ]
        }
      )
      cs
    end

    it "places {props.children} at the INSTANCE_SWAP position" do
      result = factory.generate_component_set(swap_slot_component_set)
      code = result[:code]

      expect(code).to include("{props.children}")
    end

    it "does not generate an import for the slot placeholder component" do
      result = factory.generate_component_set(swap_slot_component_set)
      code = result[:code]

      imports = code.lines.select { |l| l.strip.start_with?("import") }
      expect(imports.size).to eq(1)
      expect(imports.first).to include("React")
    end
  end

  describe "#list component with multiple identical INSTANCE_SWAP instances" do
    let(:list_component_set) do
      cs = library.component_sets.create!(
        node_id: "list:100",
        name: "ItemList #list",
        description: "",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Item" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "item:001",
            "preferredValues" => [
              { "type" => "COMPONENT_SET", "key" => "abc123" }
            ]
          }
        }
      )
      cs.variants.create!(
        node_id: "list:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "list:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "list:110",
              "type" => "FRAME",
              "name" => "container",
              "layoutMode" => "VERTICAL",
              "visible" => true,
              "children" => [
                {
                  "id" => "list:111",
                  "type" => "INSTANCE",
                  "name" => "item 1",
                  "componentId" => "item:001",
                  "visible" => true,
                  "componentPropertyReferences" => { "mainComponent" => "Item" }
                },
                {
                  "id" => "list:112",
                  "type" => "INSTANCE",
                  "name" => "item 2",
                  "componentId" => "item:001",
                  "visible" => true,
                  "componentPropertyReferences" => { "mainComponent" => "Item" }
                },
                {
                  "id" => "list:113",
                  "type" => "INSTANCE",
                  "name" => "item 3",
                  "componentId" => "item:001",
                  "visible" => true,
                  "componentPropertyReferences" => { "mainComponent" => "Item" }
                }
              ]
            }
          ]
        }
      )
      cs
    end

    it "emits exactly one {props.children} for the first slot instance" do
      result = factory.generate_component_set(list_component_set)
      code = result[:code]

      expect(code.scan("{props.children}").size).to eq(1)
    end

    it "does not import the repeated slot placeholder" do
      result = factory.generate_component_set(list_component_set)
      code = result[:code]

      imports = code.lines.select { |l| l.strip.start_with?("import") }
      expect(imports.size).to eq(1)
      expect(imports.first).to include("React")
    end
  end

  describe "INSTANCE_SWAP without preferredValues (icon swap)" do
    let(:icon_swap_component_set) do
      cs = library.component_sets.create!(
        node_id: "iconswap:100",
        name: "Button",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name,
        prop_definitions: {
          "Icon" => {
            "type" => "INSTANCE_SWAP",
            "defaultValue" => "iconarrow:001"
            # No preferredValues — not a slot
          }
        }
      )
      cs.variants.create!(
        node_id: "iconswap:101",
        name: "Default",
        is_default: true,
        figma_json: {
          "id" => "iconswap:101",
          "type" => "COMPONENT",
          "name" => "Default",
          "children" => [
            {
              "id" => "iconswap:110",
              "type" => "TEXT",
              "name" => "label",
              "characters" => "Click me",
              "visible" => true
            },
            {
              "id" => "iconswap:111",
              "type" => "INSTANCE",
              "name" => "icon instance",
              "componentId" => "iconarrow:001",
              "visible" => true,
              "componentPropertyReferences" => { "mainComponent" => "Icon" }
            }
          ]
        }
      )
      cs
    end

    it "does not treat INSTANCE_SWAP without preferredValues as a slot" do
      result = factory.generate_component_set(icon_swap_component_set)
      code = result[:code]

      expect(code).not_to include("{props.children}")
    end
  end
end
