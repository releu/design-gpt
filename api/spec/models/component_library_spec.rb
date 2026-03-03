require "rails_helper"

RSpec.describe ComponentLibrary, type: :model do
  describe "figma_file_key extraction" do
    it "extracts file key from /design/ URL" do
      ds = ComponentLibrary.create!(
        user: users(:bob),
        name: "Test DS",
        figma_url: "https://www.figma.com/design/ABC123def/my-file?node-id=0-1",
        status: "pending"
      )
      expect(ds.figma_file_key).to eq("ABC123def")
    end

    it "extracts file key from /file/ URL" do
      ds = ComponentLibrary.create!(
        user: users(:bob),
        name: "Test DS 2",
        figma_url: "https://www.figma.com/file/XYZ789abc/another-file",
        status: "pending"
      )
      expect(ds.figma_file_key).to eq("XYZ789abc")
    end
  end

  it "validates figma_url presence" do
    ds = ComponentLibrary.new(user: users(:alice), name: "No URL", status: "pending")
    expect(ds).not_to be_valid
    expect(ds.errors[:figma_url]).to include("can't be blank")
  end

  it "validates status inclusion" do
    ds = component_libraries(:example_lib)
    ds.status = "invalid_status"
    expect(ds).not_to be_valid
  end

  it "has many components" do
    expect(component_libraries(:example_lib).components.count).to be >= 2
  end

  it "has many component_sets" do
    expect(component_libraries(:example_lib).component_sets.count).to be >= 1
  end

  it "has many designs through design_component_libraries" do
    expect(component_libraries(:example_lib).designs).to include(designs(:alice_design))
  end

  describe "#figma_url_for_node" do
    it "generates correct URL" do
      ds = component_libraries(:example_lib)
      url = ds.figma_url_for_node("1:100")
      expect(url).to eq("https://www.figma.com/design/75U91YIrYa65xhYcM0olH5?node-id=1-100")
    end

    it "returns nil without file_key" do
      ds = ComponentLibrary.new
      expect(ds.figma_url_for_node("1:100")).to be_nil
    end
  end

  describe "status transitions" do
    it "allows valid status flow including comparing" do
      ds = component_libraries(:empty_ds)
      expect(ds.status).to eq("pending")

      ds.update!(status: "importing")
      ds.update!(status: "converting")
      ds.update!(status: "comparing")
      ds.update!(status: "ready")
      expect(ds.status).to eq("ready")
    end
  end

  describe "#sync_async" do
    it "enqueues a ComponentLibrarySyncJob" do
      ds = component_libraries(:empty_ds)
      expect { ds.sync_async }.to have_enqueued_job(ComponentLibrarySyncJob).with(ds.id)
      expect(ds.reload.status).to eq("pending")
      expect(ds.progress).to include("started_at")
    end
  end
end
