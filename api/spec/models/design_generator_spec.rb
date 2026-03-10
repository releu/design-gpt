require "rails_helper"

RSpec.describe DesignGenerator, type: :model do
  let(:design) { designs(:alice_design) }
  let(:library) { figma_files(:example_lib) }

  describe "#generate_task" do
    it "creates an AiTask with valid payload" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a landing page")

      expect(task).to be_a(AiTask)
      expect(task).to be_persisted
      expect(task.payload).to be_a(Hash)
      expect(task.payload["model"]).to eq("gpt-5")
    end

    it "includes system and user messages in input" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a landing page")

      input = task.payload["input"]
      expect(input.length).to eq(2)
      expect(input[0]["role"]).to eq("system")
      expect(input[1]["role"]).to eq("user")
      expect(input[1]["content"][0]["text"]).to eq("Build a landing page")
    end

    it "lists available components in the system prompt" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a landing page")

      system_text = task.payload["input"][0]["content"][0]["text"]
      # to_component_name("VStack") → "Vstack", "Button" → "Button"
      expect(system_text).to include("Vstack")
      expect(system_text).to include("Button")
      expect(system_text).to include("Badge")
      # Icons should not appear
      expect(system_text).not_to include("IconArrow")
    end

    it "builds a valid JSON Schema with $defs" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      schema = task.payload["text"]["format"]["schema"]
      expect(schema["type"]).to eq("object")
      expect(schema["additionalProperties"]).to eq(false)
      expect(schema["required"]).to eq(["tree"])
      expect(schema["properties"]["tree"]).to eq({ "$ref" => "#/$defs/AllComponents" })
      expect(schema["$defs"]).to be_a(Hash)
    end

    it "includes AllComponents anyOf with only root components" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      all_components = defs["AllComponents"]
      expect(all_components["anyOf"]).to eq([{ "$ref" => "#/$defs/Vstack" }])
    end

    it "builds correct component def with const discriminator" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      button_def = defs["Button"]

      expect(button_def["type"]).to eq("object")
      expect(button_def["additionalProperties"]).to eq(false)
      expect(button_def["properties"]["component"]).to eq({ "type" => "string", "const" => "Button" })
      expect(button_def["required"]).to include("component")
    end

    it "generates VARIANT props with enum values from variants" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      button_def = defs["Button"]

      # button_default: "Size=M, State=default", button_hover: "Size=M, State=hover"
      expect(button_def["properties"]["size"]["type"]).to eq("string")
      expect(button_def["properties"]["size"]["enum"]).to contain_exactly("M")

      expect(button_def["properties"]["state"]["type"]).to eq("string")
      expect(button_def["properties"]["state"]["enum"]).to contain_exactly("default", "hover")
    end

    it "omits children for leaf components with no @slot" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      button_def = defs["Button"]

      # Button has slots: [] and no @slot → no children field
      expect(button_def["properties"]).not_to have_key("children")
      expect(button_def["required"]).not_to include("children")
    end

    it "sets children as array with refs for container components" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      vstack_def = defs["Vstack"]

      # VStack has slots: [{name: "children", allowed_children: ["Button", "Badge"]}]
      children = vstack_def["properties"]["children"]
      expect(children["type"]).to eq("array")
      expect(children["items"]["anyOf"]).to contain_exactly(
        { "$ref" => "#/$defs/Button" },
        { "$ref" => "#/$defs/Badge" }
      )
    end

    it "includes standalone non-icon components in schema defs" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      # Badge is standalone, non-icon
      expect(defs).to have_key("Badge")
      expect(defs["Badge"]["properties"]["component"]).to eq({ "type" => "string", "const" => "Badge" })
    end

    it "excludes icon component sets from schema" do
      gen = DesignGenerator.new(design)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]
      expect(defs).not_to have_key("Iconarrow")
      expect(defs).not_to have_key("Iconclose")
    end

    it "raises error when no figma files linked" do
      design_no_lib = users(:alice).designs.create!(prompt: "test", status: "draft")
      gen = DesignGenerator.new(design_no_lib)

      expect { gen.generate_task("Build a page") }.to raise_error("No figma files linked")
    end

    it "raises error when no root components configured" do
      # Use a design system with only example_icons (no root components)
      icons_ds = DesignSystem.create!(name: "Icons Only", user: design.user, status: "ready", version: 1)
      figma_files(:example_icons).update!(design_system: icons_ds, version: 1)
      design.update!(design_system: icons_ds)
      gen = DesignGenerator.new(design.reload)

      expect { gen.generate_task("Build a page") }.to raise_error("No root components configured")
    end

    it "normalizes slot allowed_children names to match to_component_name output" do
      # Simulate Figma import: component set named "Default list" stored with
      # slots from preferredValues as raw Figma names like "Card item"
      list_set = library.component_sets.create!(
        name: "Default list",
        node_id: "1:900",
        figma_file_key: "test",
        slots: [{ "name" => "children", "allowed_children" => ["Card item"] }],
        is_root: false
      )
      library.component_sets.create!(
        name: "Card item",
        node_id: "1:901",
        figma_file_key: "test",
        slots: [],
        is_root: false
      )

      # Point VStack's children to the list using raw Figma name
      vstack = component_sets(:vstack_set)
      vstack.update!(slots: [{ "name" => "children", "allowed_children" => ["Default list"] }])

      gen = DesignGenerator.new(design.reload)
      task = gen.generate_task("Build a page")

      defs = task.payload["text"]["format"]["schema"]["$defs"]

      # All referenced $defs must exist — this is the bug that caused OpenAI schema rejection
      all_refs = defs.values.flat_map { |d| extract_refs(d) }.uniq
      all_refs.each do |ref_name|
        expect(defs).to have_key(ref_name), "Missing $def for referenced component '#{ref_name}'"
      end

      # Verify the normalized names are used (to_component_name capitalizes each word)
      expect(defs).to have_key("DefaultList")
      expect(defs).to have_key("CardItem")
    end
  end

  private

  def extract_refs(obj)
    case obj
    when Hash
      refs = []
      if obj["$ref"]
        match = obj["$ref"].match(%r{#/\$defs/(.+)})
        refs << match[1] if match
      end
      obj.each_value { |v| refs.concat(extract_refs(v)) }
      refs
    when Array
      obj.flat_map { |v| extract_refs(v) }
    else
      []
    end
  end
end
