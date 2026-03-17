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

    # --- Second library for multi-file tests ---
    second_lib = alice.figma_files.find_or_create_by!(
      figma_url: "https://www.figma.com/design/e2eSecondLib456/e2e-second-lib?node-id=0-1"
    ) do |lib|
      lib.name          = "E2E Second Library"
      lib.figma_file_key = "e2eSecondLib456"
      lib.figma_file_name = "e2e-second-lib"
      lib.status        = "ready"
      lib.progress      = {}
    end
    second_lib.update!(status: "ready") unless second_lib.status == "ready"

    # Seed a DesignSystem so the home page design system list is populated
    e2e_ds = DesignSystem.find_or_create_by!(user: alice, name: "E2E Design System")

    ready_lib = alice.figma_files.find_or_create_by!(
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
    DesignSystemLibrary.find_or_create_by!(design_system: e2e_ds, figma_file: ready_lib)
    DesignSystemLibrary.find_or_create_by!(design_system: e2e_ds, figma_file: second_lib)

    # --- "Example" design system (needed for design generation tests) ---
    example_ds = DesignSystem.find_or_create_by!(user: alice, name: "Example")
    DesignSystemLibrary.find_or_create_by!(design_system: example_ds, figma_file: ready_lib)

    # Seed a standalone component (TEXT_COMPONENT) with react_code and visual_diff score
    text_component = ready_lib.components.find_or_create_by!(node_id: "e2e:50") do |c|
      c.name           = "Text"
      c.figma_file_key = "e2eReadyLib123"
      c.figma_file_name = "e2e-ready-lib"
      c.status         = "imported"
      c.enabled        = true
      c.match_percent  = 97.0
      c.figma_json     = {
        "id" => "e2e:50", "type" => "COMPONENT", "name" => "Text",
        "children" => [{ "id" => "e2e:51", "type" => "TEXT", "name" => "content", "characters" => "Hello world" }]
      }
      c.react_code     = "export function Text(props) { return <p>{props.children || 'Hello world'}</p>; }"
      c.react_code_compiled = "var Text = function(props){return React.createElement('p',null,props.children||'Hello world');};"
    end
    text_component.update!(match_percent: 97.0)

    # Seed a standalone component with minimal react_code so the controller can
    # serve it and visual_diff/figma_json endpoints return data.
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

    # TITLE_COMPONENT as a ComponentSet with variants for VARIANT/BOOLEAN/TEXT prop tests
    # This allows the variant dropdown to have values from the variant names
    title_set = ready_lib.component_sets.find_or_create_by!(node_id: "e2e:20") do |cs|
      cs.name           = "Title"
      cs.figma_file_key = "e2eReadyLib123"
      cs.figma_file_name = "e2e-ready-lib"
      cs.prop_definitions = {
        "size"   => { "type" => "VARIANT", "defaultValue" => "m" },
        "marker" => { "type" => "BOOLEAN", "defaultValue" => "false" },
        "text"   => { "type" => "TEXT", "defaultValue" => "Hello" }
      }
    end
    title_set.update!(
      prop_definitions: {
        "size"   => { "type" => "VARIANT", "defaultValue" => "m" },
        "marker" => { "type" => "BOOLEAN", "defaultValue" => "false" },
        "text"   => { "type" => "TEXT", "defaultValue" => "Hello" }
      }
    )

    # Title variant: size=m (default)
    title_m = title_set.variants.find_or_create_by!(node_id: "e2e:21") do |v|
      v.name        = "size=m"
      v.is_default  = true
      v.match_percent = 91.0
      v.figma_json  = {
        "id" => "e2e:21", "type" => "COMPONENT", "name" => "size=m",
        "children" => [{ "id" => "e2e:22", "type" => "TEXT", "name" => "text", "characters" => "Hello" }]
      }
      v.react_code  = "export function Title(props) { return <h1>{props.text || 'Hello'}</h1>; }"
      v.react_code_compiled = "var Title = function(props){return React.createElement('h1',null,props.text||'Hello');};"
    end
    title_m.update!(match_percent: 91.0, is_default: true)

    # Title variant: size=l
    title_l = title_set.variants.find_or_create_by!(node_id: "e2e:23") do |v|
      v.name        = "size=l"
      v.is_default  = false
      v.match_percent = 99.0
      v.figma_json  = {
        "id" => "e2e:23", "type" => "COMPONENT", "name" => "size=l",
        "children" => [{ "id" => "e2e:24", "type" => "TEXT", "name" => "text", "characters" => "Hello" }]
      }
      v.react_code  = "export function Title(props) { return <h1 style={{fontSize:'32px'}}>{props.text || 'Hello'}</h1>; }"
      v.react_code_compiled = "var Title = function(props){return React.createElement('h1',{style:{fontSize:'32px'}},props.text||'Hello');};"
    end
    title_l.update!(match_percent: 99.0)

    # Remove any stale variants on Title set (only keep m and l)
    title_set.variants.where.not(node_id: ["e2e:21", "e2e:23"]).destroy_all

    # PAGE_COMPONENT as a ComponentSet with slots (root component)
    page_set = ready_lib.component_sets.find_or_create_by!(node_id: "e2e:30") do |cs|
      cs.name           = "Page"
      cs.figma_file_key = "e2eReadyLib123"
      cs.figma_file_name = "e2e-ready-lib"
      cs.is_root        = true
      cs.slots          = [{ "name" => "content", "allowed_children" => ["Title", "Text"] }]
      cs.prop_definitions = {}
    end
    page_set.update!(
      is_root: true,
      slots: [{ "name" => "content", "allowed_children" => ["Title", "Text"] }]
    )

    page_default = page_set.variants.find_or_create_by!(node_id: "e2e:31") do |v|
      v.name        = "Default"
      v.is_default  = true
      v.match_percent = 95.0
      v.figma_json  = {
        "id" => "e2e:31", "type" => "COMPONENT", "name" => "Default",
        "children" => [{ "id" => "e2e:32", "type" => "FRAME", "name" => "content" }]
      }
      v.react_code  = "export function Page(props) { return <div>{props.children}</div>; }"
      v.react_code_compiled = "var Page = function(props){return React.createElement('div',null,props.children);};"
    end
    page_default.update!(match_percent: 95.0)

    # Remove stale variants on Page set (only keep Default)
    page_set.variants.where.not(node_id: "e2e:31").destroy_all

    # Remove old standalone Title/Page components that conflict with new component sets
    ready_lib.components.where(node_id: ["e2e:20", "e2e:30"]).destroy_all

    # Component on second library (for grouped-by-file tests)
    second_lib.components.find_or_create_by!(node_id: "e2e:60") do |c|
      c.name           = "SecondButton"
      c.figma_file_key = "e2eSecondLib456"
      c.figma_file_name = "e2e-second-lib"
      c.status         = "imported"
      c.enabled        = true
      c.match_percent  = 96.0
      c.figma_json     = {
        "id" => "e2e:60", "type" => "COMPONENT", "name" => "SecondButton",
        "children" => [{ "id" => "e2e:61", "type" => "TEXT", "name" => "label", "characters" => "Go" }]
      }
      c.react_code     = "export function SecondButton(props) { return <button>Go</button>; }"
      c.react_code_compiled = "var SecondButton = function(props){return React.createElement('button',null,'Go');};"
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

    # Always ensure no-code component has no react_code (unconditionally)
    nocode_component.update!(react_code: nil, react_code_compiled: nil)

    # --- Seed designs for design management tests ---
    # Design #100 with a completed generation (for improvement/chat tests)
    design_100 = alice.designs.find_or_create_by!(name: "E2E Design #100") do |d|
      d.prompt = "A sample design for testing"
      d.status = "ready"
    end
    design_100.update!(status: "ready") unless design_100.status == "ready"

    # Link component libraries to design
    DesignFigmaFile.find_or_create_by!(design: design_100, figma_file: ready_lib)

    # Seed iterations with JSX
    if design_100.iterations.empty?
      iter = design_100.iterations.create!(
        comment: "A sample design for testing",
        jsx: '<Page><Title text="Hello World" /><Text>Welcome to the app</Text></Page>'
      )
    end

    # Seed chat messages
    if design_100.chat_messages.empty?
      design_100.chat_messages.create!(author: "user", message: "A sample design for testing", state: "completed")
      design_100.chat_messages.create!(author: "designer", message: "Here is your design with a Page containing a Title and Text component.", state: "completed")
    end

    # Seed additional designs for "List all user DESIGNs" test (needs >= 5)
    5.times do |i|
      d = alice.designs.find_or_create_by!(name: "E2E Test Design #{i + 1}") do |d|
        d.prompt = "Test design #{i + 1}"
        d.status = "ready"
      end
      DesignFigmaFile.find_or_create_by!(design: d, figma_file: ready_lib)
      if d.iterations.empty?
        d.iterations.create!(comment: "Test design #{i + 1}", jsx: "<Page><Title text=\"Design #{i + 1}\" /></Page>")
      end
    end

    # Image component set for image workflow tests
    image_set = ready_lib.component_sets.find_or_create_by!(node_id: "e2e:img100") do |cs|
      cs.name            = "Photo #image"
      cs.figma_file_key  = "e2eReadyLib123"
      cs.figma_file_name = "e2e-ready-lib"
      cs.is_image        = true
      cs.prop_definitions = {}
    end
    image_set.update!(is_image: true)

    image_set.variants.find_or_create_by!(node_id: "e2e:img101") do |v|
      v.name        = "Default"
      v.is_default  = true
      v.figma_json  = {
        "id" => "e2e:img101", "type" => "COMPONENT", "name" => "Default",
        "children" => []
      }
      v.react_code  = <<~JSX
        export function PhotoImage({ prompt, ...props }) {
          const src = prompt
            ? `https://design-gpt.xyz/api/images/render?prompt=${encodeURIComponent(prompt)}`
            : '';
          return (
            <div data-component="PhotoImage"
              style={{
                width: '100%', height: '100%',
                backgroundImage: src ? `url(${src})` : 'none',
                backgroundSize: 'cover', backgroundPosition: 'center',
              }}
              {...props} />
          );
        }
        export default PhotoImage;
      JSX
      v.react_code_compiled = "var PhotoImage = function(props){return React.createElement('div',{style:{width:'100%',height:'100%',backgroundSize:'cover'}});};"
    end

    # Pre-seed an ImageCache record for E2E tests
    ImageCache.find_or_create_by!(query: "e2e test image") do |ic|
      ic.url    = "https://avatars.mds.yandex.net/get-images/e2e/test.jpg?n=33&w=1200&h=1200"
      ic.width  = "1200"
      ic.height = "800"
    end

    # Store the component id for tests that need it
    puts "E2E image component set id: #{image_set.id}"
    puts "E2E ready library id: #{ready_lib.id}"
    puts "E2E second library id: #{second_lib.id}"
    puts "E2E ready component id: #{e2e_component.id}"
    puts "E2E ready component set id: #{e2e_set.id}"
    puts "E2E title component set id: #{title_set.id}"
    puts "E2E page component set id: #{page_set.id}"
    puts "E2E text component id: #{text_component.id}"
    puts "E2E design system id: #{e2e_ds.id}"
    puts "E2E example DS id: #{example_ds.id}"
    puts "E2E design 100 id: #{design_100.id}"
    puts "E2E fixtures loaded successfully"
  end
end
