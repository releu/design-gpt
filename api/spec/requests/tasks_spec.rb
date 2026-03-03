require "rails_helper"

RSpec.describe "Tasks API", type: :request do
  let(:user) { users(:alice) }
  let(:tasks_token) { "test-tasks-token" }
  let(:tasks_headers) { { "Authorization" => "Bearer #{tasks_token}" } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TASKS_TOKEN").and_return(tasks_token)
  end

  # These specs test controller auth logic without relying on AiTask model queries.

  describe "GET /api/tasks/next" do
    it "rejects unauthorized requests" do
      get "/api/tasks/next", headers: { "Authorization" => "Bearer wrong" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/tasks/:id" do
    before { stub_auth_for(user) }

    it "requires authentication" do
      get "/api/tasks/1"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
