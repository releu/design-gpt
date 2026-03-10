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
    it "creates a new version and enqueues a ComponentLibrarySyncJob" do
      ds = component_libraries(:empty_ds)
      new_version = nil
      expect { new_version = ds.sync_async }.to have_enqueued_job(ComponentLibrarySyncJob)
      expect(new_version).to be_a(ComponentLibrary)
      expect(new_version.id).not_to eq(ds.id)
      expect(new_version.source_library_id).to eq(ds.id)
      expect(new_version.version).to eq(2)
      expect(new_version.status).to eq("pending")
      expect(new_version.progress).to include("started_at")
    end
  end

  describe "#source" do
    it "returns self when no source_library" do
      ds = component_libraries(:example_lib)
      expect(ds.source).to eq(ds)
    end

    it "returns source_library when set" do
      ds = component_libraries(:example_lib)
      new_version = ds.sync_async
      expect(new_version.source).to eq(ds)
    end
  end

  describe "#latest_version" do
    it "returns self when no versions exist" do
      ds = component_libraries(:empty_ds)
      expect(ds.latest_version).to eq(ds)
    end

    it "returns the highest version" do
      ds = component_libraries(:empty_ds)
      v2 = ds.sync_async
      expect(ds.latest_version).to eq(v2)
    end
  end

  describe ".latest_versions" do
    it "excludes old versions that have newer ones" do
      ds = component_libraries(:empty_ds)
      v2 = ds.sync_async
      latest = ComponentLibrary.latest_versions
      expect(latest).to include(v2)
      expect(latest).not_to include(ds)
    end
  end
end
