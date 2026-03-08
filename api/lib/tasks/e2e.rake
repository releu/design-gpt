namespace :e2e do
  desc "Reset test database and load fixtures for E2E tests"
  task setup: :environment do
    abort("Only in test!") unless Rails.env.test?

    require "active_record/fixtures"
    fixtures_dir = Rails.root.join("test/fixtures")
    ActiveRecord::FixtureSet.reset_cache
    ActiveRecord::FixtureSet.create_fixtures(fixtures_dir, ["users"])

    alice = User.find_by!(auth0_id: "auth0|alice123")

    # Only remove DUPLICATE design systems (keep first, delete extras)
    %w[Example].each do |name|
      dupes = alice.design_systems.where(name: name).order(:id)
      dupes.offset(1).destroy_all if dupes.count > 1
    end

    # Seed a DesignSystem so the home page design system list is populated
    e2e_ds = DesignSystem.find_or_create_by!(user: alice, name: "E2E Design System")

    ready_lib = alice.component_libraries.find_or_create_by!(
      figma_url: "https://www.figma.com/design/e2eReadyLib123/e2e-ready-lib?node-id=0-1"
    ) do |lib|
      lib.name          = "E2E Ready Library"
      lib.figma_file_key = "e2eReadyLib123"
      lib.figma_file_name = "e2e-ready-lib"
      lib.status        = "ready"
      lib.progress      = {}
    end

    # Ensure status is ready even if it already existed
    ready_lib.update!(status: "ready") unless ready_lib.status == "ready"

    # Link library to design system
    DesignSystemLibrary.find_or_create_by!(design_system: e2e_ds, component_library: ready_lib)

    # Seed a standalone component with minimal react_code so the controller can
    # serve it and visual_diff/figma_json endpoints return data.
    # Names use hyphenated form so to_component_name("e2e-button") → "E2eButton"
    # and the compiled code matches the generated PascalCase name.
    e2e_component = ready_lib.components.find_or_create_by!(node_id: "e2e:1") do |c|
      c.name           = "e2e-button"
      c.figma_file_key = "e2eReadyLib123"
      c.figma_file_name = "e2e-ready-lib"
      c.status         = "imported"
      c.enabled        = true
      c.match_percent  = 95.0
      c.figma_json     = {
        "id" => "e2e:1", "type" => "COMPONENT", "name" => "e2e-button",
        "children" => [{ "id" => "e2e:2", "type" => "TEXT", "name" => "label", "characters" => "Click me" }]
      }
      c.react_code     = "export function E2eButton(props) { return <button>Click me</button>; }"
      c.react_code_compiled = "var E2eButton = function(props){return React.createElement('button',null,'Click me');};"
    end

    # Seed a ComponentSet with a default variant so figma_json component_set tests pass.
    e2e_set = ready_lib.component_sets.find_or_create_by!(node_id: "e2e:10") do |cs|
      cs.name           = "e2e-card"
      cs.figma_file_key = "e2eReadyLib123"
      cs.figma_file_name = "e2e-ready-lib"
      cs.prop_definitions = { "State" => { "type" => "VARIANT", "defaultValue" => "Default" } }
    end

    e2e_variant = e2e_set.variants.find_or_create_by!(node_id: "e2e:11") do |v|
      v.name        = "State=Default"
      v.is_default  = true
      v.figma_json  = {
        "id" => "e2e:11", "type" => "COMPONENT", "name" => "State=Default",
        "children" => [{ "id" => "e2e:12", "type" => "TEXT", "name" => "title", "characters" => "Card" }]
      }
      v.react_code  = "export function E2eCard(props) { return <div>Card</div>; }"
      v.react_code_compiled = "var E2eCard = function(props){return React.createElement('div',null,'Card');};"
    end

    # Seed a component with BOOLEAN and TEXT prop_definitions (for prop type tests)
    title_component = ready_lib.components.find_or_create_by!(node_id: "e2e:20") do |c|
      c.name           = "Title"
      c.figma_file_key = "e2eReadyLib123"
      c.figma_file_name = "e2e-ready-lib"
      c.status         = "imported"
      c.enabled        = true
      c.match_percent  = 90.0
      c.prop_definitions = {
        "size"   => { "type" => "VARIANT", "defaultValue" => "M" },
        "marker" => { "type" => "BOOLEAN", "defaultValue" => "false" },
        "text"   => { "type" => "TEXT", "defaultValue" => "Hello" }
      }
      c.figma_json     = {
        "id" => "e2e:20", "type" => "COMPONENT", "name" => "Title",
        "children" => [{ "id" => "e2e:21", "type" => "TEXT", "name" => "text", "characters" => "Hello" }]
      }
      c.react_code     = "export function Title(props) { return <h1>{props.text}</h1>; }"
      c.react_code_compiled = "var Title = function(props){return React.createElement('h1',null,props.text);};"
    end

    # Seed a component with slots/allowed_children (for slot tests)
    page_component = ready_lib.components.find_or_create_by!(node_id: "e2e:30") do |c|
      c.name           = "Page"
      c.figma_file_key = "e2eReadyLib123"
      c.figma_file_name = "e2e-ready-lib"
      c.status         = "imported"
      c.enabled        = true
      c.is_root        = true
      c.match_percent  = 85.0
      c.slots          = [{ "name" => "content", "allowed_children" => ["Title", "e2e-button"] }]
      c.figma_json     = {
        "id" => "e2e:30", "type" => "COMPONENT", "name" => "Page",
        "children" => [{ "id" => "e2e:31", "type" => "FRAME", "name" => "content" }]
      }
      c.react_code     = "export function Page(props) { return <div>{props.children}</div>; }"
      c.react_code_compiled = "var Page = function(props){return React.createElement('div',null,props.children);};"
    end

    # Seed a component WITHOUT react_code so the "no code" status badge test passes
    nocode_component = ready_lib.components.find_or_create_by!(node_id: "e2e:40") do |c|
      c.name           = "e2e-icon"
      c.figma_file_key = "e2eReadyLib123"
      c.figma_file_name = "e2e-ready-lib"
      c.status         = "imported"
      c.enabled        = true
      c.match_percent  = 50.0
      c.figma_json     = {
        "id" => "e2e:40", "type" => "COMPONENT", "name" => "e2e-icon",
        "children" => [{ "id" => "e2e:41", "type" => "VECTOR", "name" => "icon" }]
      }
      c.react_code     = nil
      c.react_code_compiled = nil
    end

    # Store the component id for tests that need it
    puts "E2E ready library id: #{ready_lib.id}"
    puts "E2E ready component id: #{e2e_component.id}"
    puts "E2E ready component set id: #{e2e_set.id}"
    puts "E2E title component id: #{title_component.id}"
    puts "E2E page component id: #{page_component.id}"
    puts "E2E fixtures loaded successfully"
  end
end
