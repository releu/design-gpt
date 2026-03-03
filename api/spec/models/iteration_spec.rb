require "rails_helper"

RSpec.describe Iteration, type: :model do
  it "belongs to a design" do
    expect(iterations(:first_iteration).design).to eq(designs(:alice_design))
  end

  it "has jsx content" do
    expect(iterations(:first_iteration).jsx).to eq("<div>Landing Page</div>")
  end

  it "can have nil jsx" do
    iter = Iteration.new(design: designs(:alice_design), comment: "draft")
    expect(iter.jsx).to be_nil
  end

  it "has optional render association" do
    expect(iterations(:first_iteration).render).to be_nil
  end
end
