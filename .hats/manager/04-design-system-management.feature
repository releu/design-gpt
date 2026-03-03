@design-system
Feature: Design System Management
  Users create design systems by grouping one or more component libraries under a name.
  Design systems serve as the component palette for AI design generation.
  Technical: DesignSystem has_many ComponentLibraries through DesignSystemLibraries.
  Configuration (is_root, allowed_children) is set automatically from Figma conventions.
  UI reference: designer/06-design-system-modal.md (full-screen modal),
  designer/04-home-new-design.md (design system panel on home page)

  Background:
    Given the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: Design system modal opens as full-screen overlay
    Given the user is on the home page
    When the user clicks "new" in the design system panel
    Then a full-screen overlay should appear with background matching --bg-modal-overlay
    And a close button (x) should be visible in the top-left corner of the overlay (~36px circle, white bg, black x)
    And a centered modal card should appear (~65% viewport width, ~70% viewport height)
    And the modal card should have white background, 24px border-radius, subtle shadow, and 24px padding

  @critical @happy-path
  Scenario: Design system modal has two-pane layout
    Given the design system modal is open
    Then the modal should have a left navigation sidebar (~35% width)
    And a right content area (~65% width)
    And the left sidebar should show a "general" section header with "overview" item below it
    And clicking "overview" should highlight it with a light gray background

  @critical @happy-path
  Scenario: Create a new design system via the modal
    Given the user has imported a Figma component library that is "ready"
    When the user clicks "new" in the design system panel on the home page
    Then the design system modal should appear with the overview pane active
    And the right panel should show a name text input field
    When the user enters "My Design System" in the name input
    And adds a Figma URL in the "add figma file" input and clicks "add"
    Then the import progress should be visible in the overview area
    When the import completes
    Then the left sidebar should list components grouped by Figma file name
    And the name should be saved automatically (on blur or modal close -- no explicit Save button)
    When the user closes the modal
    Then a DesignSystem should be created with name "My Design System"
    And the DesignSystem should be linked to the imported component libraries
    And the design system should appear in the library selector on the home page

  @critical @happy-path
  Scenario: Create a design system via API
    Given 2 ready component libraries exist with ids 10 and 11
    When the user sends POST /api/design-systems with name "Test DS" and component_library_ids [10, 11]
    Then the response status should be 201
    And the response should contain the design system id and name "Test DS"

  @happy-path
  Scenario: List user's design systems
    Given the user has 2 design systems
    When the user sends GET /api/design-systems
    Then the response should contain 2 design systems
    And each should include id, name, component_library_ids, and libraries array

  @happy-path
  Scenario: Modal overview pane shows design system details
    Given the user has a design system "Example" with 2 linked Figma files
    When the user clicks "edit" next to the "Example" design system on the home page
    Then the design system modal should open with the overview pane active
    And the right panel should show the label "design system" in bold
    And a text input should contain the name "Example"
    And the "figma files" section should list 2 files as bullet items
    And each file item should show: file name (linked), "open" link, "remove" link
    And below the file list there should be an "add figma file" input with an "add" button
    And an "actions:" section should contain a "sync with figma" link

  @happy-path
  Scenario: Browse components in the left sidebar organized by Figma file
    Given the design system modal is open with components from 2 Figma files
    Then the left sidebar should show:
      | section              | items                                  |
      | general              | overview                               |
      | figma-file-1-name    | ComponentA, ComponentB, ComponentC     |
      | figma-file-2-name    | ComponentD, ComponentE                 |
    And file names should appear as gray section headers (13px, secondary text)
    And component names should be indented (~16px left padding) in primary text (14px)
    And the sidebar should scroll independently if the component list overflows

  @happy-path
  Scenario: View component detail in the modal
    Given the design system modal is open with imported components
    When the user clicks on a component "Button" in the left sidebar
    Then the selected component should get a light gray highlight background
    And the right panel should show the ComponentDetail view
    And the component name "Button" should be displayed (16px, bold)
    And a "link to figma" link should open the Figma component in a new tab
    And a "sync with figma" link should trigger re-import of this specific component
    And the component type badge should show "Component Set" (pill-shaped)
    And the status badge should indicate the import status ("ready", "importing", or "no code")

  @happy-path
  Scenario: Component detail shows props with type-dependent controls
    Given the user is viewing a component "Button" in the modal
    Then the "props" section should list each prop with an interactive control:
      | prop_type | control                                  |
      | VARIANT   | Dropdown/select with all variant values   |
      | TEXT      | Text input field                          |
      | BOOLEAN   | Checkbox                                  |
    And changing any prop value should send a postMessage to the live preview iframe with updated JSX

  @happy-path
  Scenario: Component detail shows live preview
    Given the user is viewing a component "Button" in the modal
    Then a "live preview" section should show a bordered iframe (1px solid border)
    And the iframe should render the component with the current prop values
    And the iframe should take full width of the right pane (~200-300px height)
    When the user changes a prop value
    Then the preview should update in real-time

  @happy-path
  Scenario: Interactive prop editing updates preview
    Given the user is viewing a component "Button" with a VARIANT prop "State" having values ["default", "hover", "pressed"]
    When the user selects "hover" from the "State" dropdown
    Then the preview iframe should re-render the component with the "hover" state
    And the generated JSX should include the updated prop value

  @happy-path
  Scenario: Component detail shows React code section
    Given the user is viewing a component "Button" that has generated React code
    Then an expandable/collapsible "React code" section should be present
    And expanding it should show a read-only CodeMirror editor with the component's React source code
    And the editor should use monospace font with JSX syntax highlighting

  @happy-path
  Scenario: View AI Schema shows component tree reachable from root
    Given the design system modal is open with a root component "Page" that allows children ["Title", "Text"]
    When the user clicks "AI Schema" in the left menu
    Then the AI Schema view should display a tree starting from "Page"
    And "Title" and "Text" should appear as allowed children under "Page"
    And the subtitle should explain "Components reachable from root"

  @happy-path
  Scenario: Component configuration is read-only (set by Figma conventions)
    Given the user is viewing a component "Page" that is marked as root
    And "Page" has allowed_children ["Title", "Button"]
    When the user opens the Configuration section
    Then the root badge should show "yes"
    And the allowed children should list "Title" and "Button"
    And these fields should not be editable in the UI

  @happy-path
  Scenario: Close modal via close button
    Given the design system modal is open
    When the user clicks the close button (x) in the top-left of the overlay
    Then the modal should close
    And the underlying page should be revealed

  @happy-path
  Scenario: Close modal by clicking overlay background
    Given the design system modal is open
    When the user clicks the overlay background (outside the modal card)
    Then the modal should close
    And any name changes should be auto-saved

  @edge-case
  Scenario: Design system with no root components shows empty AI Schema
    Given the design system has no components with is_root set to true
    When the user views the AI Schema
    Then the view should display "No root components found. Mark components with #root in Figma."

  @edge-case
  Scenario: Component with no React code shows "no code" status
    Given a component exists that failed React code generation
    When the user views the component detail
    Then the status badge should show "no code" in a warning style
