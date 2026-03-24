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

    it "always uses the current DS version, not a pinned one" do
      ds = design_systems(:alice_ds)
      design = designs(:alice_design)

      # Create iteration — it no longer pins a version
      iteration = design.iterations.create!(
        comment: "test",
        jsx: "<Button />",
        design_system: ds
      )

      # Simulate DS sync: bump version to 2 with new files
      new_lib = ds.figma_files.create!(
        user: ds.user, name: "v2 lib", version: 2, status: "ready",
        figma_url: "https://figma.com/test", figma_file_key: "test123"
      )
      new_lib.component_sets.create!(
        node_id: "v2:100", name: "Button",
        figma_file_key: "test123", figma_file_name: "test",
        prop_definitions: {}
      ).variants.create!(
        node_id: "v2:101", name: "Default", is_default: true,
        figma_json: { "id" => "v2:101", "type" => "COMPONENT", "name" => "Default", "children" => [] },
        react_code_compiled: "var Button = function() { return React.createElement('button', null, 'v2'); }"
      )
      ds.update!(version: 2)

      get "/api/iterations/#{iteration.id}/renderer"

      expect(response).to have_http_status(:ok)
      # Should use v2 components (the current DS version), not v1
      expect(response.body).to include("v2")
    end
  end
end
