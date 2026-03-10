require "rails_helper"

RSpec.describe "Design Systems API", type: :request do
  let(:user) { users(:alice) }
  let(:bob) { users(:bob) }
  let(:ds) { design_systems(:alice_ds) }
  let(:library) { figma_files(:example_lib) }

  before { stub_auth_for(user) }

  describe "GET /api/design-systems" do
    it "returns user's design systems with library info" do
      get "/api/design-systems", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("My Design System")
      expect(json.first["libraries"]).to be_an(Array)
      expect(json.first["libraries"].length).to eq(2)
    end

    it "does not return other users' design systems" do
      stub_auth_for(bob)
      get "/api/design-systems", headers: auth_headers(bob)

      json = JSON.parse(response.body)
      expect(json).to be_empty
    end
  end

  describe "POST /api/design-systems" do
    it "creates a design system with linked libraries" do
      expect {
        post "/api/design-systems",
          params: { design_system: { name: "New DS", figma_file_ids: [library.id] } },
          headers: auth_headers(user)
      }.to change(DesignSystem, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New DS")

      new_ds = DesignSystem.find(json["id"])
      expect(new_ds.figma_file_ids).to eq([library.id])
    end

    it "returns 422 when name is missing" do
      post "/api/design-systems",
        params: { design_system: { name: "", figma_file_ids: [library.id] } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
