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

    context "when iteration is created during DS sync" do
      it "pins to the last ready version, not the in-progress version" do
        ds = design_systems(:alice_ds)
        design = designs(:alice_design)

        # DS version is 1 (has files). Simulate sync_async: status changes
        # but version stays at 1 until sync completes.
        ds.update!(status: "pending")

        iteration = design.iterations.create!(
          comment: "test",
          jsx: "<Button />",
          design_system: ds,
          design_system_version: ds.version
        )

        # Version is still 1 (the ready version), so components load
        expect(iteration.design_system_version).to eq(1)

        get "/api/iterations/#{iteration.id}/renderer"

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/_loaded = \[.*"Button"/)
      end
    end
  end
end
