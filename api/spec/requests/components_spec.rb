require "rails_helper"

RSpec.describe "Components API", type: :request do
  let(:user) { users(:alice) }

  before { stub_auth_for(user) }

  describe "PATCH /api/components/:id" do
    it "toggles enabled status" do
      comp = components(:divider)
      patch "/api/components/#{comp.id}",
        params: { component: { enabled: false } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(comp.reload.enabled).to be false
    end

    it "updates status" do
      comp = components(:card_with_icon)
      patch "/api/components/#{comp.id}",
        params: { component: { status: "skipped" } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(comp.reload.status).to eq("skipped")
    end
  end

  describe "GET /api/components/:id/figma-json" do
    it "returns the component figma_json" do
      comp = components(:divider)
      get "/api/components/#{comp.id}/figma-json", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["figma_json"]).to be_present
      expect(json["figma_json"]["type"]).to eq("COMPONENT")
    end
  end

  describe "GET /api/components/:id/html-preview" do
    it "returns HTML preview for a component with html_code" do
      comp = components(:divider)
      get "/api/components/#{comp.id}/html-preview", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("divider")
    end
  end

  describe "GET /api/components/:id/visual-diff" do
    it "returns visual diff results" do
      comp = components(:divider)
      comp.update!(match_percent: 95.5, diff_image_path: "/tmp/diff.png")

      get "/api/components/#{comp.id}/visual-diff", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["match_percent"]).to eq(95.5)
      expect(json["has_diff"]).to be true
    end

    it "returns null match_percent when no diff has been run" do
      comp = components(:badge)

      get "/api/components/#{comp.id}/visual-diff", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["match_percent"]).to be_nil
      expect(json["has_diff"]).to be false
    end
  end

  describe "GET /api/components/:id/diff-image" do
    it "returns 404 when no diff image exists" do
      comp = components(:divider)

      get "/api/components/#{comp.id}/diff-image", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/components/:id/screenshots/:type" do
    it "returns 404 when no figma screenshot exists" do
      comp = components(:divider)

      get "/api/components/#{comp.id}/screenshots/figma", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 for unknown screenshot type" do
      comp = components(:divider)

      get "/api/components/#{comp.id}/screenshots/unknown", headers: auth_headers(user)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/component-sets/:id/figma-json" do
    it "returns the default variant figma_json" do
      cs = component_sets(:button_set)
      get "/api/component-sets/#{cs.id}/figma-json", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["figma_json"]).to be_present
    end
  end
end
