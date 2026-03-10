require "rails_helper"

RSpec.describe DesignSystem, type: :model do
  let(:user) { users(:alice) }
  let(:ds) { design_systems(:alice_ds) }

  describe "associations" do
    it "belongs to a user" do
      expect(ds.user).to eq(user)
    end

    it "has many figma files through design_system_libraries" do
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
end
