require "rails_helper"

RSpec.describe Design, type: :model do
  it "belongs to user" do
    expect(designs(:alice_design).user).to eq(users(:alice))
  end

  it "accesses figma_files through design_system" do
    expect(designs(:alice_design).figma_files).to include(figma_files(:example_lib))
  end

  it "is accessible through user.designs" do
    expect(users(:alice).designs).to include(designs(:alice_design))
  end

  it "validates status inclusion" do
    design = designs(:alice_design)
    design.status = "invalid"
    expect(design).not_to be_valid
  end

  describe "#set_default_name" do
    it "sets name from prompt on create" do
      design = users(:alice).designs.create!(
        prompt: "A beautiful dashboard with charts",
        status: "draft"
      )
      expect(design.name).to eq("A beautiful dashboard with charts")
    end

    it "preserves explicit name" do
      design = users(:alice).designs.create!(
        prompt: "A dashboard",
        name: "Custom Name",
        status: "draft"
      )
      expect(design.name).to eq("Custom Name")
    end
  end

  describe "#duplicate" do
    it "creates a copy with last iteration" do
      design = designs(:alice_design)
      copy = design.duplicate

      expect(copy).to be_persisted
      expect(copy.name).to include("(copy)")
      expect(copy.design_system_id).to eq(design.design_system_id)
      expect(copy.iterations.count).to eq(1)
      expect(copy.status).to eq("ready")
    end
  end

  describe "#last_jsx" do
    it "returns JSX from the last iteration" do
      design = designs(:alice_design)
      expect(design.last_jsx).to be_present
    end
  end

  describe "#to_frontend_json" do
    it "includes all expected fields" do
      json = designs(:alice_design).to_frontend_json
      expect(json).to have_key(:id)
      expect(json).to have_key(:name)
      expect(json).to have_key(:status)
      expect(json).to have_key(:iterations)
      expect(json).to have_key(:chat)
    end
  end
end
