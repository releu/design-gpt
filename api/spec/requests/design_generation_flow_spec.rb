require "rails_helper"

RSpec.describe "Design generation flow", type: :request do
  let(:user) { users(:alice) }
  let(:library) { component_libraries(:example_lib) }

  before { stub_auth_for(user) }

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
                    { "component" => "Button", "children" => "Hello World" }
                  ]
                }
              }.to_json
            }
          ]
        }
      ]
    }
  end

  it "creates design, enqueues AI job, processes response, and returns JSX" do
    expect {
      post "/api/designs",
        params: { design: { prompt: "A hello world page", component_library_ids: [library.id] } },
        headers: auth_headers(user)
    }.to have_enqueued_job(AiRequestJob)

    expect(response).to have_http_status(:created)
    design_id = JSON.parse(response.body)["id"]
    design = Design.find(design_id)

    expect(design.status).to eq("generating")
    expect(design.iterations.count).to eq(1)
    expect(design.chat_messages.where(author: "user").count).to eq(1)
    expect(design.chat_messages.where(author: "designer", state: "thinking").count).to eq(1)

    ai_task = AiTask.last
    expect(ai_task.state).to eq("pending")
    expect(ai_task.payload).to be_present

    # Simulate AiRequestJob completing
    iteration = design.iterations.last
    designer_message = design.chat_messages.find_by(author: "designer")

    ai_task.update!(result: openai_response, state: "completed")
    iteration.update!(jsx: ai_task.jsx)
    designer_message.update!(state: "completed", message: "Done")
    design.update!(status: "ready")

    expect(iteration.reload.jsx).to include("VStack")

    get "/api/designs/#{design_id}", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("ready")
    expect(json["iterations"].last["jsx"]).to include("VStack")
    expect(json["iterations"].last["completed"]).to be true
    expect(json["chat"].any? { |m| m["author"] == "designer" && m["state"] == "completed" }).to be true
  end

  it "supports improve (chat iteration) flow" do
    design = designs(:alice_design)

    expect {
      post "/api/designs/#{design.id}/improve",
        params: { comment: "Make the buttons bigger" },
        headers: auth_headers(user)
    }.to have_enqueued_job(AiRequestJob)

    expect(response).to have_http_status(:ok)
    design.reload

    expect(design.status).to eq("generating")
    expect(design.iterations.count).to eq(3) # 2 existing + 1 new
    expect(design.chat_messages.where(author: "user").last.message).to eq("Make the buttons bigger")
    expect(design.chat_messages.where(author: "designer", state: "thinking").count).to be >= 1

    # Simulate completion
    new_iteration = design.iterations.order(:id).last
    ai_task = AiTask.last
    ai_task.update!(result: openai_response, state: "completed")
    new_iteration.update!(jsx: ai_task.jsx)
    design.update!(status: "ready")

    get "/api/designs/#{design.id}", headers: auth_headers(user)
    json = JSON.parse(response.body)

    expect(json["iterations"].length).to eq(3)
    expect(json["iterations"].last["jsx"]).to include("VStack")
  end

  it "renders component library HTML for iframe preview" do
    get "/api/component-libraries/#{library.id}/renderer"

    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include("unpkg.com/react@18")
    expect(body).to include("Babel.transform")
    expect(body).to include("postMessage")
  end
end
