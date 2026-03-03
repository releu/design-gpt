@design-generation
Feature: Design Generation
  Users enter a text prompt and select a design system. The backend generates
  a JSON tree via AI (structured output matching the component schema),
  transforms it to JSX, and the frontend renders it in a preview iframe.
  Technical: Design status flow: draft -> generating -> ready | error.
  Pipeline: DesignGenerator builds JSON Schema -> AiRequestJob calls OpenAI ->
  AiTask stores result -> JsonToJsx transforms to JSX -> Iteration stores JSX.
  Frontend polls GET /api/designs/:id every 1s while status is "generating".

  Background:
    Given the user is logged in as "alice@example.com"
    And a design system "Example" exists with root component "Page" and children ["Title", "Text"]

  @critical @happy-path
  Scenario: Generate a design from a prompt
    Given the user is on the home page
    When the user enters the prompt "List top 5 parks in Amsterdam"
    And selects the design system "Example"
    And clicks "Generate"
    Then a POST request should be sent to /api/designs with the prompt and design_system_id
    And the user should be redirected to /designs/:id
    And the design page should show the chat panel and preview area
    And the preview should show "Generated design will appear here" (empty state)

  @critical @happy-path
  Scenario: Design generation completes and preview renders
    Given a design exists with status "generating" and design_id 42
    When the AI request job completes successfully
    Then an Iteration should be created with the generated JSX
    And the design status should change to "ready"
    And the frontend should detect the status change via polling
    And the preview iframe should render the generated JSX
    And the rendered content should contain design-specific text (e.g. park names)

  @critical @happy-path
  Scenario: Create design via API
    Given a design system exists with id 5
    When the user sends POST /api/designs with prompt "Hello world" and design_system_id 5
    Then the response should contain the new design id
    And the design status should be "generating"
    And an AiRequestJob should be enqueued

  @happy-path
  Scenario: View mode switching between mobile, desktop, and code
    Given the user is on a design page with a completed design
    When the user clicks the mobile view switcher
    Then the preview should render in mobile layout (rounded iframe)
    When the user clicks the desktop view switcher
    Then the preview should render in desktop layout (wider iframe)
    When the user clicks the code view switcher "</>"
    Then the code editor should display the raw JSX code

  @happy-path
  Scenario: Design page shows design name and allows switching between designs
    Given the user has 3 designs
    When the user is on a design page
    Then the top bar should show the current design name
    And a dropdown should list all user designs
    When the user selects a different design from the dropdown
    Then the page should navigate to that design

  @happy-path
  Scenario: Navigate from design page back to new design
    Given the user is on a design page
    When the user selects "(+) new design" from the design dropdown
    Then the user should be redirected to the home page

  @happy-path
  Scenario: Schema generation builds valid JSON Schema from component library
    Given a component library with a root "Page" component set having props:
      | prop_name | prop_type | values              |
      | Layout    | VARIANT   | default, wide       |
      | Title     | TEXT      |                     |
      | ShowIcon  | BOOLEAN   |                     |
    And "Page" allows children ["Card", "Title"]
    When DesignGenerator builds the schema
    Then the schema should define "Page" with:
      | property  | type   | constraint         |
      | layout    | string | enum: default,wide |
      | title     | string |                    |
      | showIcon  | boolean|                    |
    And "Page" should be listed in the root anyOf
    And children should reference "Card" and "Title" definitions

  @happy-path
  Scenario: JSON to JSX transformation produces valid output
    Given an AI response with a JSON tree:
      """
      {
        "type": "Page",
        "props": { "layout": "wide", "title": "Hello" },
        "children": [
          { "type": "Title", "props": { "text": "Welcome" }, "children": [] }
        ]
      }
      """
    When JsonToJsx transforms the tree
    Then the output JSX should be:
      """
      <Page layout="wide" title="Hello">
        <Title text="Welcome" />
      </Page>
      """

  @happy-path
  Scenario: Renderer iframe loads and accepts JSX via postMessage
    Given a component library has compiled React code for all components
    When the renderer page is loaded at /api/component-libraries/:id/renderer
    Then React, ReactDOM, and Babel should be loaded
    And all component code should be injected
    And a postMessage listener should be active
    When a message { type: "render", jsx: "<Button>Test</Button>" } is sent
    Then the iframe should render a Button component with text "Test"

  @happy-path
  Scenario: Polling stops when design reaches "ready" status
    Given a design page is open for a design with status "generating"
    And the frontend is polling every 1 second
    When the design status changes to "ready"
    Then the polling should stop
    And no further GET requests should be made to /api/designs/:id

  @edge-case
  Scenario: New user with no design systems sees Generate button disabled
    Given the user has no design systems
    And the user is on the home page
    Then the "Generate" button should be disabled
    And a hint should be visible indicating the user needs to create a design system first
    When the user clicks the disabled "Generate" button
    Then no request should be made
    And the user should remain on the home page

  @edge-case
  Scenario: Design with no design system returns error
    When the user sends POST /api/designs with a prompt but no design_system_id or component_library_ids
    Then the design should fail because no component libraries are linked

  @happy-path
  Scenario: Code view is editable with syntax highlighting
    Given the user is on a design page with a completed design
    When the user clicks the code view switcher "</>"
    Then the code editor should display the generated JSX
    And the code editor should use CodeMirror with JSX syntax highlighting
    And the code should be editable (not read-only)

  @happy-path
  Scenario: Editing JSX in code view triggers live preview update
    Given the user is viewing the code editor with the current iteration's JSX
    When the user edits the JSX code (e.g. changes a text prop value)
    Then the preview iframe should re-render with the updated JSX
    And the re-render should happen automatically without pressing a button

  @happy-path
  Scenario: Code changes are auto-saved
    Given the user is viewing the code editor with the current iteration's JSX
    When the user edits the JSX code
    Then the changes should be saved automatically to the current iteration
    And no explicit "Save" button should be required

  @happy-path
  Scenario: Reset JSX to a previous iteration via chat
    Given a design has 3 iterations with different JSX versions
    And the chat panel displays messages for each iteration
    When the user clicks the reset button on the second iteration's chat message
    Then the code editor should revert to the JSX from the second iteration
    And the preview should re-render with that iteration's JSX

  @error-handling
  Scenario: AI request fails and design status becomes error
    Given a design is being generated
    When the AI request job fails (OpenAI error or timeout)
    Then the design status should change to "error"
    And the frontend should stop polling
    And the user should see an indication that generation failed
