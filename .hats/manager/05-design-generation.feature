@design-generation
Feature: Design Generation
  Users enter a text prompt and select a design system. The backend generates
  a JSON tree via AI (structured output matching the component schema),
  transforms it to JSX, and the frontend renders it in a preview iframe.
  Technical: Design status flow: draft -> generating -> ready | error.
  Pipeline: DesignGenerator builds JSON Schema -> AiRequestJob calls OpenAI ->
  AiTask stores result -> JsonToJsx transforms to JSX -> Iteration stores JSX.
  Frontend polls GET /api/designs/:id every 1s while status is "generating".
  UI reference: designer/04-home-new-design.md (home page layout),
  designer/05-design-page.md (design page layouts and views),
  designer/02-layout-structures.md (four layout patterns)

  Background:
    Given the user is logged in as "alice@example.com"
    And a design system "Example" exists with root component "Page" and children ["Title", "Text"]

  # --- Home Page Layout ---

  @critical @happy-path
  Scenario: Home page displays three-column layout with bottom bar
    Given the user is on the home page
    Then the page should use Layout 1: three columns + bottom bar
    And the left column (~33%) should contain the prompt panel
    And the center column (~33%) should contain the design system panel
    And the right column (~33%) should contain the preview frame (full height from header to bottom)
    And a bottom bar should span the left and center columns (not the preview column)
    And columns should be separated by vertical drag-handle dividers (1px line with small bar indicator)

  @critical @happy-path
  Scenario: Prompt panel accepts design description
    Given the user is on the home page
    Then the prompt panel should be a white card with 24px border-radius and 16px padding
    And a "prompt" label should appear above the content area (13px, weight 500)
    And a large multi-line textarea should fill the available space
    And the textarea placeholder should read "describe what you want to create" in secondary text color
    When the user enters the prompt "List top 5 parks in Amsterdam"
    Then the text should appear in the textarea (14px, primary text color)

  @critical @happy-path
  Scenario: Design system panel shows library list
    Given the user has design systems with libraries "common/depot", "releu/depot", "andreas/cubes"
    And the user is on the home page
    Then the design system panel should be a white card with "design system" label
    And the panel should show a scrollable list of available libraries
    And each library row should show the library name (14px, primary text)
    And the selected library should have a subtle background highlight and an "edit" link on the right
    And a pill-shaped "new" button should appear at the bottom-left of the panel

  @critical @happy-path
  Scenario: AI engine bar with generate button
    Given the user is on the home page
    Then the AI engine bar should appear as a bottom strip (~60px height) below the prompt and design system panels
    And the bar should show an "ai engine" label above the content
    And the content should display "ChatGPT" in bold (14px) as the engine name
    And a subtitle "don't share nda for now" should appear in secondary text (12px)
    And a pill-shaped "generate" button should be right-aligned
    And the "generate" button should have near-black background (#1A1A1A) with white text

  @critical @happy-path
  Scenario: Generate a design from a prompt
    Given the user is on the home page
    When the user enters the prompt "List top 5 parks in Amsterdam"
    And selects the design system "Example" by clicking on it in the library list
    And clicks "generate"
    Then a POST request should be sent to /api/designs with the prompt and design_system_id
    And the user should be redirected to /designs/:id
    And the design page should show the chat panel and preview area

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

  # --- Home Page Interactions ---

  @happy-path
  Scenario: Clicking a design system name selects it
    Given the user is on the home page with multiple design systems
    When the user clicks on a design system name "releu/depot"
    Then "releu/depot" should become highlighted with a light gray background
    And an "edit" link should appear on the right side of the selected row

  @happy-path
  Scenario: Edit link on design system opens the modal
    Given the user is on the home page with a selected design system
    When the user clicks "edit" on the selected design system
    Then the design system modal should open for that library (see 04-design-system-management)

  @happy-path
  Scenario: New button in design system panel opens modal in create mode
    Given the user is on the home page
    When the user clicks the "new" button at the bottom of the design system panel
    Then the design system modal should open in create mode

  @happy-path
  Scenario: Preview selector on home page changes preview frame style
    Given the user is on the home page
    Then the preview selector in the header should show "phone", "desktop", "code" pills
    When the user selects "phone"
    Then the preview frame should show with 72px border-radius (phone bezel)
    When the user selects "desktop"
    Then the preview frame should show with 24px border-radius (desktop card)
    When the user selects "code"
    Then the preview frame should switch to a code editor view

  @happy-path
  Scenario: Home page preview frame shows placeholder
    Given the user is on the home page with no design generated yet
    Then the preview frame in the right column should show "preview" centered in secondary text color
    And the frame should have a 2px solid black border with phone bezel styling (72px radius) by default

  # --- Design Page View Modes ---

  @happy-path
  Scenario: Phone view uses two-column layout (Layout 2)
    Given the user is on a design page with a completed design
    And the preview selector shows "phone" as active
    Then the page should use Layout 2: two columns
    And the left column (~60%) should contain the chat panel
    And the right column (~40%) should contain the phone-frame preview
    And the phone frame should be centered vertically in its column
    And a vertical drag-handle divider should separate the two columns

  @happy-path
  Scenario: Desktop view uses stacked layout (Layout 3)
    Given the user is on a design page with a completed design
    When the user clicks "desktop" in the preview selector
    Then the page should use Layout 3: header + stacked content
    And the chat panel should take full width with reduced height (top portion)
    And the desktop preview frame should take full width below the chat
    And the desktop frame should have 2px solid black border and 24px border-radius
    And a horizontal drag-handle divider should separate chat from preview allowing vertical resize

  @happy-path
  Scenario: Code view uses three-column layout (Layout 4)
    Given the user is on a design page with a completed design
    When the user clicks "code" in the preview selector
    Then the page should use Layout 4: three columns
    And the left column (~25%) should contain the chat panel (narrow, messages wrap earlier)
    And the center column (~42%) should contain the CodeMirror editor with JSX syntax highlighting
    And the right column (~33%) should contain the phone-frame preview
    And two vertical drag-handle dividers should separate the three columns

  @happy-path
  Scenario: Design page shows design name in selector dropdown
    Given the user has 3 designs
    When the user is on a design page
    Then the design selector in the header should show the current design name (e.g. "design #12")
    And the selector should be pill-shaped with a dropdown caret
    When the user clicks the design selector
    Then a dropdown should appear listing "(+) new design" first, then all user designs ordered by most recent
    When the user selects a different design from the dropdown
    Then the page should navigate to that design

  @happy-path
  Scenario: Navigate from design page back to new design
    Given the user is on a design page
    When the user selects "(+) new design" from the design dropdown
    Then the user should be redirected to the home page

  # --- Generating State ---

  @happy-path
  Scenario: Design page during generating state
    Given the user has just created a design and is on the design page
    And the design status is "generating"
    Then the preview area may show a loading indicator or "preview" placeholder text
    And the chat input send button should be disabled
    And the frontend should poll GET /api/designs/:id every 1 second
    When the design status changes to "ready"
    Then the polling should stop
    And no further GET requests should be made to /api/designs/:id
    And the preview iframe should render the generated design

  # --- Schema and JSX ---

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

  # --- Code View ---

  @happy-path
  Scenario: Code view is editable with syntax highlighting
    Given the user is on a design page with a completed design
    When the user clicks "code" in the preview selector
    Then the center column should display the CodeMirror editor
    And the editor should show the generated JSX with syntax highlighting (JSX/HTML mode)
    And the code should be editable (not read-only)
    And the editor should use monospace font at 13px
    And line numbers should be visible in the gutter

  @happy-path
  Scenario: Editing JSX in code view triggers live preview update
    Given the user is viewing the code editor in the center column
    When the user edits the JSX code (e.g. changes a text prop value)
    Then the phone-frame preview in the right column should re-render with the updated JSX
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

  # --- Edge Cases ---

  @edge-case
  Scenario: New user with no design systems sees Generate button disabled
    Given the user has no design systems
    And the user is on the home page
    Then the design system panel should show an empty list
    And the "new" button should be prominently visible
    And the "generate" button in the AI engine bar should be disabled (gray, no pointer cursor)
    And a hint text like "Create a design system to get started" should appear
    When the user clicks the disabled "generate" button
    Then no request should be made
    And the user should remain on the home page

  @edge-case
  Scenario: Design with no design system returns error
    When the user sends POST /api/designs with a prompt but no design_system_id or component_library_ids
    Then the design should fail because no component libraries are linked

  # --- Error Handling ---

  @error-handling
  Scenario: AI request fails and design status becomes error
    Given a design is being generated
    When the AI request job fails (OpenAI error or timeout)
    Then the design status should change to "error"
    And the frontend should stop polling
    And the preview area should show an error indication
    And the chat panel may show a system message indicating failure
    And the user can retry by sending a new improvement message
