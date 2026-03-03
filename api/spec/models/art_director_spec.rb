require "rails_helper"

RSpec.describe ArtDirector, type: :model do
  let(:design) { designs(:alice_design) }

  before do
    # Attach a render to the last iteration for the art director to reference
    render = Render.create!(image: "PNG_DATA", token: "test-art-token")
    design.iterations.order(:id).last.update!(render: render)
  end

  describe "#analyze" do
    it "creates an AiTask with the review payload" do
      ad = ArtDirector.new(design)

      expect { ad.analyze }.to change(AiTask, :count).by(1)

      task = AiTask.last
      expect(task.state).to eq("pending")
      expect(task.payload["model"]).to eq("gpt-5")
    end

    it "includes component descriptions from the library" do
      ad = ArtDirector.new(design)
      task = ad.analyze

      # The payload input should contain component descriptions
      user_messages = task.payload["input"].select { |m| m["role"] == "user" }
      descriptions_msg = user_messages.find { |m| m["content"].is_a?(String) && m["content"].include?("available components") }

      expect(descriptions_msg).to be_present
      expect(descriptions_msg["content"]).to include("Button")
    end

    it "includes the render screenshot reference" do
      ad = ArtDirector.new(design)
      task = ad.analyze

      user_messages = task.payload["input"].select { |m| m["role"] == "user" }
      screenshot_msg = user_messages.find { |m|
        m["content"].is_a?(Array) && m["content"].any? { |c| c["type"] == "input_image" && c["image_url"]&.include?("renders") }
      }

      expect(screenshot_msg).to be_present
    end

    it "uses json_schema response format with verdict and feedback" do
      ad = ArtDirector.new(design)
      task = ad.analyze

      schema = task.payload["text"]["format"]["schema"]
      expect(schema["required"]).to include("verdict", "feedback")
      expect(schema["properties"]["verdict"]["enum"]).to eq(["ok", "shit"])
    end
  end
end
