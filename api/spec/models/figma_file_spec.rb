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

  it "has many designs through design_figma_files" do
    expect(figma_files(:example_lib).designs).to include(designs(:alice_design))
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

  describe "#sync_async" do
    it "creates a new version and enqueues a FigmaFileSyncJob" do
      ff = figma_files(:empty_ds)
      new_version = nil
      expect { new_version = ff.sync_async }.to have_enqueued_job(FigmaFileSyncJob)
      expect(new_version).to be_a(FigmaFile)
      expect(new_version.id).not_to eq(ff.id)
      expect(new_version.source_file_id).to eq(ff.id)
      expect(new_version.version).to eq(2)
      expect(new_version.status).to eq("pending")
      expect(new_version.progress).to include("started_at")
    end
  end

  describe "#source" do
    it "returns self when no source_file" do
      ff = figma_files(:example_lib)
      expect(ff.source).to eq(ff)
    end

    it "returns source_file when set" do
      ff = figma_files(:example_lib)
      new_version = ff.sync_async
      expect(new_version.source).to eq(ff)
    end
  end

  describe "#latest_version" do
    it "returns self when no versions exist" do
      ff = figma_files(:empty_ds)
      expect(ff.latest_version).to eq(ff)
    end

    it "returns the highest version" do
      ff = figma_files(:empty_ds)
      v2 = ff.sync_async
      expect(ff.latest_version).to eq(v2)
    end
  end

  describe ".latest_versions" do
    it "excludes old versions that have newer ones" do
      ff = figma_files(:empty_ds)
      v2 = ff.sync_async
      latest = FigmaFile.latest_versions
      expect(latest).to include(v2)
      expect(latest).not_to include(ff)
    end
  end
end
