require "rails_helper"

RSpec.describe "Renderer Endpoints", type: :request do
  describe "GET /api/design-systems/:id/renderer" do
    let(:ds) { design_systems(:alice_ds) }

    it "returns HTML without auth" do
      get "/api/design-systems/#{ds.id}/renderer"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<!DOCTYPE html>")
      expect(response.body).to include("react")
    end

    it "returns 404 for nonexistent ID" do
      get "/api/design-systems/0/renderer"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/iterations/:id/renderer" do
    let(:iteration) { iterations(:first_iteration) }

    it "returns HTML without auth" do
      get "/api/iterations/#{iteration.id}/renderer"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<!DOCTYPE html>")
      expect(response.body).to include("react")
    end

    it "returns 404 for nonexistent ID" do
      get "/api/iterations/0/renderer"

      expect(response).to have_http_status(:not_found)
    end
  end
end
