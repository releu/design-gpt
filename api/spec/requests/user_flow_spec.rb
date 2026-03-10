require "rails_helper"

RSpec.describe "Full User Flow", type: :request do
  let(:user) { users(:alice) }

  before { stub_auth_for(user) }

  it "end-to-end: import figma file, create design, view components, manage" do
    headers = auth_headers(user)

    # === Step 1: Create a figma file from a Figma URL ===
    post "/api/figma-files",
      params: { url: "https://www.figma.com/design/E2Ekey111/e2e-lib", name: "E2E Lib" },
      headers: headers
    expect(response).to have_http_status(:created)
    ds_id = JSON.parse(response.body)["id"]

    ds = FigmaFile.find(ds_id)
    expect(ds.figma_file_key).to eq("E2Ekey111")
    expect(ds.status).to eq("pending")

    # === Step 2: Sync the figma file (import from Figma) ===
    mock_client = instance_double(Figma::Client)
    allow(Figma::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:get)
      .with("/v1/files/E2Ekey111")
      .and_return(load_figma_fixture("example_lib"))
    allow_any_instance_of(Figma::AssetExtractor).to receive(:extract_all)
    allow_any_instance_of(Figma::ReactFactory).to receive(:generate_all)

    post "/api/figma-files/#{ds_id}/sync", headers: headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["status"]).to eq("pending")

    # Execute the enqueued sync job inline
    perform_enqueued_jobs
    ds.reload
    expect(ds.status).to eq("ready")

    # === Step 3: View discovered components ===
    get "/api/figma-files/#{ds_id}/components", headers: headers
    expect(response).to have_http_status(:ok)
    components_data = JSON.parse(response.body)

    # Should have Button component set
    button = components_data["component_sets"].find { |cs| cs["name"] == "Button" }
    expect(button).to be_present
    expect(button["variants_count"]).to eq(2)

    # Should have standalone components
    expect(components_data["components"].map { |c| c["name"] }).to include("Divider", "Badge")

    # === Step 4: Disable a component ===
    divider = components_data["components"].find { |c| c["name"] == "Divider" }
    patch "/api/components/#{divider['id']}",
      params: { component: { enabled: false } },
      headers: headers
    expect(response).to have_http_status(:ok)
    expect(Component.find(divider["id"]).enabled).to be false

    # === Step 5: Re-enable it ===
    patch "/api/components/#{divider['id']}",
      params: { component: { enabled: true } },
      headers: headers
    expect(response).to have_http_status(:ok)
    expect(Component.find(divider["id"]).enabled).to be true

    # === Step 6: Create a design system, then a design using it ===
    post "/api/design-systems",
      params: { design_system: { name: "E2E DS", figma_file_ids: [ds_id] } },
      headers: headers
    expect(response).to have_http_status(:created)
    design_system_id = JSON.parse(response.body)["id"]

    allow_any_instance_of(Design).to receive(:generate)

    post "/api/designs",
      params: { design: { prompt: "A simple dashboard", design_system_id: design_system_id } },
      headers: headers
    expect(response).to have_http_status(:created)
    design_id = JSON.parse(response.body)["id"]

    design = Design.find(design_id)
    expect(design.design_system_id).to eq(design_system_id)

    # === Step 7: List designs ===
    get "/api/designs", headers: headers
    expect(response).to have_http_status(:ok)
    designs_list = JSON.parse(response.body)
    expect(designs_list.map { |d| d["id"] }).to include(design_id)
  end
end
