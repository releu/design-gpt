require "rails_helper"

RSpec.describe ChatMessage, type: :model do
  it "has a design_id" do
    expect(chat_messages(:user_message).design_id).to eq(designs(:alice_design).id)
  end

  it "returns html with line breaks for user messages" do
    msg = chat_messages(:user_message)
    expect(msg.html).to eq("Build a landing page")
  end

  it "returns as_frontend_json with html method" do
    json = chat_messages(:user_message).as_frontend_json
    expect(json["html"]).to be_present
    expect(json["author"]).to eq("user")
  end
end
