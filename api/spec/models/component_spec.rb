require "rails_helper"

RSpec.describe Component, type: :model do
  it "belongs to figma_file" do
    expect(components(:divider).figma_file).to eq(figma_files(:example_lib))
  end

  describe "#vector?" do
    it "returns true for vector-only components" do
      # Divider has a RECTANGLE child which is a vector type
      expect(components(:divider)).to be_vector
    end

    it "returns false for components with non-vector children" do
      # Badge has a FRAME > TEXT structure
      expect(components(:badge)).not_to be_vector
    end
  end

  describe "#figma_url" do
    it "generates correct URL" do
      url = components(:divider).figma_url
      expect(url).to include("figma.com/design/75U91YIrYa65xhYcM0olH5")
      expect(url).to include("node-id=1-200")
    end
  end

  describe "#instance_references" do
    it "collects INSTANCE componentIds" do
      refs = components(:card_with_icon).instance_references
      expect(refs).to include("2:201") # References IconClose
    end

    it "returns empty for leaf components" do
      expect(components(:divider).instance_references).to be_empty
    end
  end

  describe "status validation" do
    it "allows valid statuses" do
      %w[pending imported error skipped].each do |status|
        comp = components(:divider)
        comp.status = status
        expect(comp).to be_valid, "Expected #{status} to be valid"
      end
    end

    it "rejects invalid status" do
      comp = components(:divider)
      comp.status = "bogus"
      expect(comp).not_to be_valid
    end
  end

  describe "scopes" do
    it ".enabled returns enabled components" do
      expect(Component.enabled).to include(components(:divider), components(:badge))
    end

    it ".imported returns components with imported status" do
      expect(Component.imported).to include(components(:divider), components(:badge))
      expect(Component.imported).not_to include(components(:card_with_icon))
    end
  end
end
