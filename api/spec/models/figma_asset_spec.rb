require "rails_helper"

RSpec.describe FigmaAsset, type: :model do
  it "belongs to a component_set" do
    expect(figma_assets(:arrow_svg).component_set).to eq(component_sets(:icon_arrow_set))
  end

  it "validates node_id presence" do
    asset = FigmaAsset.new(asset_type: "svg")
    expect(asset).not_to be_valid
    expect(asset.errors[:node_id]).to include("can't be blank")
  end

  it "validates asset_type inclusion" do
    asset = FigmaAsset.new(node_id: "1:1", asset_type: "invalid")
    expect(asset).not_to be_valid
    expect(asset.errors[:asset_type]).to be_present
  end

  it "scopes svgs" do
    expect(FigmaAsset.svgs).to include(figma_assets(:arrow_svg))
  end

  it "returns owner" do
    expect(figma_assets(:arrow_svg).owner).to eq(component_sets(:icon_arrow_set))
  end
end
