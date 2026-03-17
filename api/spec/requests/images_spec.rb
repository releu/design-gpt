require "rails_helper"

RSpec.describe "Images API", type: :request do
  fixtures :users

  let(:user) { users(:alice) }
  let(:image_result) { { url: "https://example.com/img.jpg", width: "1200", height: "800" } }

  before do
    stub_auth_for(user)
    allow(ImageCache).to receive(:search).and_return(image_result)
  end

  describe "GET /api/images/render" do
    it "proxies image bytes with CORS headers" do
      stub_request(:get, "https://example.com/img.jpg")
        .to_return(status: 200, body: "fake-image-bytes", headers: { "Content-Type" => "image/jpeg" })

      get "/api/images/render", params: { prompt: "modern office" }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("image/jpeg")
      expect(response.body).to eq("fake-image-bytes")
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end

    it "returns 400 for blank prompt" do
      get "/api/images/render", params: { prompt: "" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 for missing prompt" do
      get "/api/images/render"
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 on error" do
      allow(ImageCache).to receive(:search).and_raise(StandardError.new("fail"))

      get "/api/images/render", params: { prompt: "error" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/images" do
    it "returns 401 without auth" do
      allow(Auth0Service).to receive(:decode_token).and_raise(StandardError.new("unauthorized"))

      get "/api/images", params: { q: "office" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns results with auth" do
      get "/api/images", params: { q: "office" }, headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
    end
  end
end
