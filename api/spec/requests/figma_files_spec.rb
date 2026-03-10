require "rails_helper"

RSpec.describe "Figma Files API", type: :request do
  let(:user) { users(:alice) }

  before { stub_auth_for(user) }

  describe "GET /api/figma-files" do
    it "returns user's figma files" do
      get "/api/figma-files", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to be >= 2

      lib = json.find { |ds| ds["name"] == "Example Lib" }
      expect(lib).to be_present
      expect(lib["status"]).to eq("ready")
      expect(lib["figma_file_name"]).to eq("example-lib")
    end
  end

  describe "POST /api/figma-files" do
    it "creates a new figma file from Figma URL" do
      expect {
        post "/api/figma-files",
          params: { url: "https://www.figma.com/design/NEWkey123/new-ds", name: "New DS" },
          headers: auth_headers(user)
      }.to change(FigmaFile, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      ds = FigmaFile.find(json["id"])
      expect(ds.figma_file_key).to eq("NEWkey123")
      expect(ds.status).to eq("pending")
    end
  end

  describe "GET /api/figma-files/:id" do
    it "returns figma file details" do
      ds = figma_files(:example_lib)
      get "/api/figma-files/#{ds.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Example Lib")
      expect(json["figma_file_key"]).to eq("75U91YIrYa65xhYcM0olH5")
      expect(json["component_sets_count"]).to eq(ds.component_sets.count)
      expect(json["components_count"]).to eq(ds.components.count)
    end
  end

  describe "POST /api/figma-files/:id/sync" do
    it "enqueues a sync job and returns pending status" do
      ds = figma_files(:empty_ds)

      expect {
        post "/api/figma-files/#{ds.id}/sync", headers: auth_headers(user)
      }.to have_enqueued_job(FigmaFileSyncJob).with(ds.id)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("pending")
      expect(json["progress"]).to include("started_at")
    end
  end

  describe "PATCH /api/figma-files/:id" do
    it "updates name and is_public" do
      cl = figma_files(:example_lib)
      patch "/api/figma-files/#{cl.id}",
        params: { figma_file: { name: "Updated Name", is_public: true } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Updated Name")
      expect(json["is_public"]).to be true
    end
  end

  describe "GET /api/figma-files/available" do
    it "returns own libraries and public ones" do
      get "/api/figma-files/available", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.any? { |lib| lib["is_own"] }).to be true
    end
  end

  describe "GET /api/figma-files/:id/renderer" do
    it "returns HTML with React, Babel, and postMessage listener without auth" do
      cl = figma_files(:example_lib)
      get "/api/figma-files/#{cl.id}/renderer"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/html")

      body = response.body
      expect(body).to include("unpkg.com/react@18")
      expect(body).to include("unpkg.com/react-dom@18")
      expect(body).to include("@babel/standalone")
      expect(body).to include("postMessage")
      expect(body).to include("Babel.transform")
      expect(body).to include("type: 'ready'")
    end

    it "includes compiled component code from variants" do
      cl = figma_files(:example_lib)
      get "/api/figma-files/#{cl.id}/renderer"

      body = response.body
      expect(body).to include("window.Button")
    end

    it "includes CSS from components" do
      cl = figma_files(:example_lib)
      get "/api/figma-files/#{cl.id}/renderer"

      body = response.body
      expect(body).to include(".divider")
    end
  end

  describe "GET /api/figma-files/:id/components" do
    it "returns component sets and standalone components" do
      ds = figma_files(:example_lib)
      get "/api/figma-files/#{ds.id}/components", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["component_sets"]).to be_an(Array)
      expect(json["components"]).to be_an(Array)

      button = json["component_sets"].find { |cs| cs["name"] == "Button" }
      expect(button).to be_present
      expect(button["variants_count"]).to eq(2)
      expect(button["variants"].find { |v| v["is_default"] }).to be_present

      divider = json["components"].find { |c| c["name"] == "Divider" }
      expect(divider).to be_present
      expect(divider["status"]).to eq("imported")
      expect(divider["has_html"]).to be true
    end
  end
end
