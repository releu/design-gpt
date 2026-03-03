require "rails_helper"

RSpec.describe "Renders API", type: :request do
  describe "GET /api/renders/:token" do
    it "returns the render image by token" do
      get "/api/renders/test-render-token-123"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("image/png")
    end

    it "returns 404 for unknown token" do
      get "/api/renders/nonexistent-token"
      expect(response).to have_http_status(:not_found)
    end
  end
end
