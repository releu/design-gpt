require "rails_helper"

RSpec.describe AiRequestJob, type: :job do
  let(:design) { designs(:alice_design) }
  let(:iteration) { iterations(:first_iteration) }
  let(:designer_message) do
    design.chat_messages.create!(author: "designer", message: "", state: "thinking")
  end

  let(:openai_response) do
    {
      "output" => [
        {
          "type" => "message",
          "content" => [
            {
              "text" => {
                "tree" => {
                  "component" => "VStack",
                  "size" => "m",
                  "children" => [
                    { "component" => "Button", "children" => "Click me" }
                  ]
                }
              }.to_json
            }
          ]
        }
      ]
    }
  end

  describe "#perform with :set_jsx action" do
    it "updates iteration with generated JSX" do
      task = AiTask.create!(payload: { model: "gpt-5" })

      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(status: 200, body: openai_response.to_json, headers: { "Content-Type" => "application/json" })

      allow_any_instance_of(Design).to receive(:render_last_iteration)

      AiRequestJob.perform_now(task.id, iteration.id, designer_message.id, :set_jsx)

      task.reload
      expect(task.state).to eq("completed")
      expect(task.result).to be_present

      iteration.reload
      expect(iteration.jsx).to include("VStack")

      designer_message.reload
      expect(designer_message.state).to eq("completed")
      expect(designer_message.message).to include("Version")
    end

    it "sets design status to ready" do
      task = AiTask.create!(payload: { model: "gpt-5" })

      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(status: 200, body: openai_response.to_json, headers: { "Content-Type" => "application/json" })

      allow_any_instance_of(Design).to receive(:render_last_iteration)

      design.update!(status: "generating")
      AiRequestJob.perform_now(task.id, iteration.id, designer_message.id, :set_jsx)

      expect(design.reload.status).to eq("ready")
    end

    it "sets design status to error on failure" do
      task = AiTask.create!(payload: { model: "gpt-5" })

      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(status: 500, body: "Internal Server Error")

      design.update!(status: "generating")

      expect {
        AiRequestJob.perform_now(task.id, iteration.id, designer_message.id, :set_jsx)
      }.to raise_error(JSON::ParserError)

      expect(design.reload.status).to eq("error")
      expect(task.reload.state).to eq("error")
    end

    it "sets design status to error on OpenAI API error response" do
      task = AiTask.create!(payload: { model: "gpt-5" })
      error_response = { "error" => { "message" => "Invalid model", "type" => "invalid_request_error" } }

      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(status: 400, body: error_response.to_json, headers: { "Content-Type" => "application/json" })

      design.update!(status: "generating")

      expect {
        AiRequestJob.perform_now(task.id, iteration.id, designer_message.id, :set_jsx)
      }.to raise_error(RuntimeError, /OpenAI API error/)

      expect(design.reload.status).to eq("error")
      expect(task.reload.state).to eq("error")
      expect(designer_message.reload.message).to include("Generation failed")
    end
  end

  describe "#perform without action" do
    it "only updates the task" do
      task = AiTask.create!(payload: { model: "gpt-5" })

      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(status: 200, body: openai_response.to_json, headers: { "Content-Type" => "application/json" })

      AiRequestJob.perform_now(task.id)

      task.reload
      expect(task.state).to eq("completed")
      expect(task.result).to be_present
    end
  end
end
