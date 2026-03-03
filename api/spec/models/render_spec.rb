require "rails_helper"

RSpec.describe Render, type: :model do
  it "generates a token before create" do
    r = Render.create!(image: "test")
    expect(r.token).to be_present
    expect(r.token).to match(/\A[0-9a-f-]{36}\z/)
  end

  it "can be found by token" do
    expect(Render.find_by_token!("test-render-token-123")).to eq(renders(:alice_render))
  end

  it "raises RecordNotFound for unknown token" do
    expect { Render.find_by_token!("nonexistent") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
