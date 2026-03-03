require "rails_helper"

RSpec.describe ComponentVariant, type: :model do
  it "belongs to component_set" do
    expect(component_variants(:button_default).component_set).to eq(component_sets(:button_set))
  end

  it "delegates component_library to component_set" do
    expect(component_variants(:button_default).component_library).to eq(component_libraries(:example_lib))
  end

  it "delegates figma_file_key to component_set" do
    expect(component_variants(:button_default).figma_file_key).to eq("75U91YIrYa65xhYcM0olH5")
  end

  describe "#figma_url" do
    it "generates correct URL" do
      url = component_variants(:button_default).figma_url
      expect(url).to include("figma.com/design/75U91YIrYa65xhYcM0olH5")
      expect(url).to include("node-id=1-101")
    end
  end

  describe "#variant_properties" do
    it "parses name with key=value pairs" do
      props = component_variants(:button_default).variant_properties
      expect(props["size"]).to eq("M")
      expect(props["state"]).to eq("default")
    end

    it "returns hash for simple names" do
      props = component_variants(:icon_arrow_default).variant_properties
      expect(props).to be_a(Hash)
    end
  end

  describe ".default scope" do
    it "returns only default variants" do
      defaults = ComponentVariant.default
      expect(defaults).to include(component_variants(:button_default))
      expect(defaults).not_to include(component_variants(:button_hover))
    end
  end
end
