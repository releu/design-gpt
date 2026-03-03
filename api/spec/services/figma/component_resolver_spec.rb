require "rails_helper"

RSpec.describe Figma::ComponentResolver do
  describe "resolving from a single component library" do
    let(:ds) { component_libraries(:example_lib) }
    let(:resolver) { described_class.new(ds) }

    it "resolves standalone components by node_id" do
      result = resolver.resolve(components(:divider).node_id)
      expect(result).to be_present
      expect(result[:type]).to eq(:component)
      expect(result[:component]).to eq(components(:divider))
      expect(result[:html]).to eq(components(:divider).html_code)
    end

    it "returns nil for unknown componentId" do
      expect(resolver.resolve("999:999")).to be_nil
    end

    it "caches results" do
      node_id = components(:divider).node_id
      result1 = resolver.resolve(node_id)
      result2 = resolver.resolve(node_id)
      expect(result1).to equal(result2) # same object
    end
  end

  describe "resolving variants" do
    let(:ds) { component_libraries(:example_lib) }
    let(:resolver) { described_class.new(ds) }

    it "resolves a variant by its node_id" do
      result = resolver.resolve(component_variants(:button_default).node_id)
      expect(result).to be_present
      expect(result[:type]).to eq(:variant)
      expect(result[:variant]).to eq(component_variants(:button_default))
      expect(result[:component_set]).to eq(component_sets(:button_set))
    end
  end

  describe "resolving component sets" do
    let(:ds) { component_libraries(:example_lib) }
    let(:resolver) { described_class.new(ds) }

    it "resolves a component set by its node_id (returns default variant)" do
      result = resolver.resolve(component_sets(:button_set).node_id)
      expect(result).to be_present
      expect(result[:type]).to eq(:component_set)
      expect(result[:variant]).to eq(component_variants(:button_default))
    end
  end

  describe "cross-file resolution with multiple libraries" do
    let(:libraries) { [component_libraries(:example_lib), component_libraries(:example_icons)] }
    let(:resolver) { described_class.new(libraries) }

    it "resolves components from both linked component libraries" do
      # From example_lib
      divider_result = resolver.resolve(components(:divider).node_id)
      expect(divider_result).to be_present
      expect(divider_result[:component]).to eq(components(:divider))

      # From example_icons (through icon_close_set -> icon_close_default variant)
      icon_result = resolver.resolve(component_variants(:icon_close_default).node_id)
      expect(icon_result).to be_present
      expect(icon_result[:type]).to eq(:variant)
    end

    it "resolves cross-file INSTANCE reference (Button -> IconArrow)" do
      # Button default variant references componentId "2:101" (IconArrow from icons lib)
      icon_arrow_result = resolver.resolve("2:101")
      expect(icon_arrow_result).to be_present
      expect(icon_arrow_result[:variant]).to eq(component_variants(:icon_arrow_default))
    end
  end

  describe "#resolvable?" do
    let(:resolver) { described_class.new([component_libraries(:example_lib), component_libraries(:example_icons)]) }

    it "returns true for known components" do
      expect(resolver.resolvable?(components(:divider).node_id)).to be true
      expect(resolver.resolvable?(component_variants(:button_default).node_id)).to be true
    end

    it "returns false for unknown componentIds" do
      expect(resolver.resolvable?("999:999")).to be false
    end
  end

  describe "#unresolved_references" do
    let(:resolver) { described_class.new(component_libraries(:example_lib)) }

    it "detects cross-file references that can't be resolved in a single DS" do
      # card_with_icon references "2:201" (IconClose from icons lib)
      # which is NOT in example_lib alone
      figma_json = components(:card_with_icon).figma_json
      unresolved = resolver.unresolved_references(figma_json)
      expect(unresolved).to include("2:201")
    end

    context "with multiple libraries" do
      let(:resolver) { described_class.new([component_libraries(:example_lib), component_libraries(:example_icons)]) }

      it "resolves cross-file references when both DS are linked" do
        figma_json = components(:card_with_icon).figma_json
        unresolved = resolver.unresolved_references(figma_json)
        expect(unresolved).to be_empty
      end
    end
  end

  describe "with array of component libraries" do
    it "accepts array of component libraries" do
      ds_list = [component_libraries(:example_lib), component_libraries(:example_icons)]
      resolver = described_class.new(ds_list)

      expect(resolver.resolvable?(components(:divider).node_id)).to be true
      expect(resolver.resolvable?(component_variants(:icon_arrow_default).node_id)).to be true
    end
  end
end
