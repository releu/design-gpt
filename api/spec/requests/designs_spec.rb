require "rails_helper"

RSpec.describe "Designs API", type: :request do
  let(:user) { users(:alice) }
  let(:ds) { design_systems(:alice_ds) }
  let(:design) { designs(:alice_design) }

  before { stub_auth_for(user) }

  describe "GET /api/designs" do
    it "returns user's designs with metadata" do
      get "/api/designs", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first).to include("id", "prompt", "design_system_id", "name", "status")
    end
  end

  describe "POST /api/designs" do
    it "creates a design and triggers generation" do
      allow_any_instance_of(Design).to receive(:generate) { |d| d.update!(status: "generating") }

      expect {
        post "/api/designs",
          params: { design: { prompt: "A login page", design_system_id: ds.id } },
          headers: auth_headers(user)
      }.to change(Design, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      new_design = Design.find(json["id"])
      expect(new_design.status).to eq("generating")
      expect(new_design.name).to be_present
    end

    it "accepts a custom name" do
      allow_any_instance_of(Design).to receive(:generate)

      post "/api/designs",
        params: { design: { prompt: "Dashboard", name: "My Dashboard", design_system_id: ds.id } },
        headers: auth_headers(user)

      json = JSON.parse(response.body)
      expect(Design.find(json["id"]).name).to eq("My Dashboard")
    end
  end

  describe "GET /api/designs/:id" do
    it "returns design with iterations, chat, and metadata" do
      get "/api/designs/#{design.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("iterations", "chat", "name", "status", "id")
      expect(json["name"]).to eq("Landing Page Design")
    end
  end

  describe "PATCH /api/designs/:id" do
    it "updates design name" do
      patch "/api/designs/#{design.id}",
        params: { design: { name: "Updated Name" } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(design.reload.name).to eq("Updated Name")
    end
  end

  describe "DELETE /api/designs/:id" do
    it "destroys a design" do
      delete "/api/designs/#{design.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:no_content)
      expect(Design.find_by(id: design.id)).to be_nil
    end
  end

  describe "POST /api/designs/:id/duplicate" do
    it "duplicates a design with iterations" do
      post "/api/designs/#{design.id}/duplicate", headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to include("(copy)")

      new_design = Design.find(json["id"])
      expect(new_design.iterations.count).to eq(1)
      expect(new_design.status).to eq("ready")
    end
  end

  describe "POST /api/designs/:id/improve" do
    it "triggers improvement" do
      allow_any_instance_of(Design).to receive(:improve)

      post "/api/designs/#{design.id}/improve",
        params: { comment: "Make it more colorful" },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/designs/:id/export-image" do
    it "returns 404 when no screenshot exists" do
      get "/api/designs/#{design.id}/export-image", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end

    it "returns PNG when screenshot exists" do
      render_record = Render.create!(image: "FAKE_PNG_DATA")
      design.iterations.order(:id).last.update!(render: render_record)

      get "/api/designs/#{design.id}/export-image", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("image/png")
    end
  end

  describe "GET /api/designs/:id/export-react" do
    it "returns 404 when no JSX exists" do
      design.iterations.update_all(jsx: nil)
      get "/api/designs/#{design.id}/export-react", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end

    it "returns a zip file when JSX exists" do
      get "/api/designs/#{design.id}/export-react", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/zip")
    end
  end

  describe "GET /api/designs/:id/export-figma" do
    it "returns design data as JSON" do
      get "/api/designs/#{design.id}/export-figma", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["design_id"]).to eq(design.id)
      expect(json["jsx"]).to be_present
    end

    it "returns 404 when no iteration has JSX" do
      design.iterations.update_all(jsx: nil)
      get "/api/designs/#{design.id}/export-figma", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
