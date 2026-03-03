require "rails_helper"

RSpec.describe "Custom Components", type: :request do
  let(:user) { users(:alice) }
  let(:library) { component_libraries(:example_lib) }

  before { stub_auth_for(user) }

  describe "POST /api/custom-components" do
    it "creates a custom component" do
      expect {
        post "/api/custom-components",
          params: {
            component: {
              name: "CustomCard",
              description: "A custom card component",
              react_code: "function CustomCard(props) { return <div className='card'>{props.children}</div>; }",
              component_library_id: library.id,
              prop_types: { title: "string", size: "enum:sm,md,lg", active: "boolean" }
            }
          },
          headers: auth_headers(user)
      }.to change(Component, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("CustomCard")
      expect(json["source"]).to eq("upload")

      component = Component.find(json["id"])
      expect(component.source).to eq("upload")
      expect(component.react_code).to include("CustomCard")
      expect(component.react_code_compiled).to include("window.CustomCard")
      expect(component.prop_definitions["title"]["type"]).to eq("TEXT")
      expect(component.prop_definitions["size"]["type"]).to eq("VARIANT")
      expect(component.prop_definitions["active"]["type"]).to eq("BOOLEAN")
    end

    it "creates a root component with allowed_children" do
      post "/api/custom-components",
        params: {
          component: {
            name: "CustomLayout",
            description: "A layout container",
            react_code: "function CustomLayout(props) { return <div>{props.children}</div>; }",
            component_library_id: library.id,
            is_root: true,
            allowed_children: ["Button", "Badge"]
          }
        },
        headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      component = Component.find(JSON.parse(response.body)["id"])
      expect(component.is_root).to be true
      expect(component.allowed_children).to eq(["Button", "Badge"])
    end
  end

  describe "PATCH /api/custom-components/:id" do
    it "updates a custom component" do
      component = library.components.create!(
        name: "ToUpdate",
        react_code: "function ToUpdate() { return <div/>; }",
        source: "upload",
        node_id: "upload-test123",
        status: "imported",
        enabled: true
      )

      patch "/api/custom-components/#{component.id}",
        params: { component: { name: "UpdatedName", description: "New description" } },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(component.reload.name).to eq("UpdatedName")
    end
  end

  describe "DELETE /api/custom-components/:id" do
    it "destroys a custom component" do
      component = library.components.create!(
        name: "ToDelete",
        react_code: "function ToDelete() { return <div/>; }",
        source: "upload",
        node_id: "upload-del123",
        status: "imported",
        enabled: true
      )

      expect {
        delete "/api/custom-components/#{component.id}", headers: auth_headers(user)
      }.to change(Component, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "rejects deletion of figma-sourced components" do
      figma_component = components(:divider)

      delete "/api/custom-components/#{figma_component.id}", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end
  end
end
