require "rails_helper"

RSpec.describe ComponentSet, type: :model do
  it "belongs to figma_file" do
    expect(component_sets(:button_set).figma_file).to eq(figma_files(:example_lib))
  end

  it "has many variants" do
    expect(component_sets(:button_set).variants.count).to eq(2)
  end

  describe "#default_variant" do
    it "returns the variant with is_default true" do
      cs = component_sets(:button_set)
      expect(cs.default_variant).to eq(component_variants(:button_default))
      expect(cs.default_variant.is_default).to be true
    end
  end

  describe "#vector?" do
    it "returns true for vector-only component sets" do
      expect(component_sets(:icon_arrow_set)).to be_vector
    end

    it "returns false for non-vector component sets" do
      expect(component_sets(:button_set)).not_to be_vector
    end
  end

  describe "#figma_url" do
    it "generates correct URL" do
      url = component_sets(:button_set).figma_url
      expect(url).to include("figma.com/design/75U91YIrYa65xhYcM0olH5")
      expect(url).to include("node-id=1-100")
    end
  end

  describe "status validation" do
    it "is valid with allowed statuses" do
      cs = component_sets(:button_set)
      %w[pending imported error skipped].each do |s|
        cs.status = s
        expect(cs).to be_valid, "expected status '#{s}' to be valid"
      end
    end

    it "is valid with nil status" do
      cs = component_sets(:button_set)
      cs.status = nil
      expect(cs).to be_valid
    end

    it "is invalid with an unknown status" do
      cs = component_sets(:button_set)
      cs.status = "bogus"
      expect(cs).not_to be_valid
    end
  end

  it "validates node_id uniqueness within figma_file" do
    cs = ComponentSet.new(
      figma_file: figma_files(:example_lib),
      node_id: "1:100", # same as button_set
      name: "Duplicate"
    )
    expect(cs).not_to be_valid
  end
end
