require "rails_helper"

RSpec.describe DesignSystem, type: :model do
  let(:user) { users(:alice) }
  let(:ds) { design_systems(:alice_ds) }

  describe "associations" do
    it "belongs to a user" do
      expect(ds.user).to eq(user)
    end

    it "has many figma files" do
      expect(ds.figma_files.count).to eq(2)
    end
  end

  describe "validations" do
    it "requires a name" do
      ds = DesignSystem.new(user: user, name: nil)
      expect(ds).not_to be_valid
      expect(ds.errors[:name]).to include("can't be blank")
    end
  end

  describe "#sync_async" do
    before do
      allow(DesignSystemSyncJob).to receive(:perform_later)
    end

    it "does not bump version until sync completes" do
      original_version = ds.version
      ds.sync_async

      ds.reload
      expect(ds.version).to eq(original_version)
      expect(ds.status).to eq("pending")
    end

    it "enqueues the sync job with the next version number" do
      ds.sync_async
      expect(DesignSystemSyncJob).to have_received(:perform_later).with(ds.id, 2)
    end
  end
end
