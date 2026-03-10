require "rails_helper"

RSpec.describe FigmaFile, type: :model do
  describe "figma_file_key extraction" do
    it "extracts file key from /design/ URL" do
      ff = FigmaFile.create!(
        user: users(:bob),
        name: "Test DS",
        figma_url: "https://www.figma.com/design/ABC123def/my-file?node-id=0-1",
        status: "pending"
      )
      expect(ff.figma_file_key).to eq("ABC123def")
    end

    it "extracts file key from /file/ URL" do
      ff = FigmaFile.create!(
        user: users(:bob),
        name: "Test DS 2",
        figma_url: "https://www.figma.com/file/XYZ789abc/another-file",
        status: "pending"
      )
      expect(ff.figma_file_key).to eq("XYZ789abc")
    end
  end

  it "validates figma_url presence" do
    ff = FigmaFile.new(user: users(:alice), name: "No URL", status: "pending")
    expect(ff).not_to be_valid
    expect(ff.errors[:figma_url]).to include("can't be blank")
  end

  it "validates status inclusion" do
    ff = figma_files(:example_lib)
    ff.status = "invalid_status"
    expect(ff).not_to be_valid
  end

  it "has many components" do
    expect(figma_files(:example_lib).components.count).to be >= 2
  end

  it "has many component_sets" do
    expect(figma_files(:example_lib).component_sets.count).to be >= 1
  end

  it "is linked to designs through design systems" do
    ds = design_systems(:alice_ds)
    expect(ds.figma_files).to include(figma_files(:example_lib))
    expect(ds.designs).to include(designs(:alice_design))
  end

  it "belongs to a design system" do
    ff = figma_files(:example_lib)
    expect(ff.design_system).to eq(design_systems(:alice_ds))
  end

  describe "#figma_url_for_node" do
    it "generates correct URL" do
      ff = figma_files(:example_lib)
      url = ff.figma_url_for_node("1:100")
      expect(url).to eq("https://www.figma.com/design/75U91YIrYa65xhYcM0olH5?node-id=1-100")
    end

    it "returns nil without file_key" do
      ff = FigmaFile.new
      expect(ff.figma_url_for_node("1:100")).to be_nil
    end
  end

  describe "status transitions" do
    it "allows valid status flow including comparing" do
      ff = figma_files(:empty_ds)
      expect(ff.status).to eq("pending")

      ff.update!(status: "importing")
      ff.update!(status: "converting")
      ff.update!(status: "comparing")
      ff.update!(status: "ready")
      expect(ff.status).to eq("ready")
    end
  end
end
