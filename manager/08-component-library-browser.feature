@component-browser
Feature: Component Library Browser
  Users can browse their imported component libraries, view individual components
  with live preview, inspect React code, and see visual diff results.
  Technical: Libraries page at /libraries, detail at /libraries/:id.
  Preview page at /api/component-libraries/:id/preview renders all components.
  ComponentDetail supports interactive props (VARIANT dropdowns, TEXT inputs, BOOLEAN checkboxes).
  The ComponentDetail view is shared between:
  - The design system modal (06-design-system-modal.md)
  - The settings panel on the design page (05-design-page.md)
  - The standalone library detail page (/libraries/:id)
  UI reference: designer/06-design-system-modal.md, designer/05-design-page.md (settings view)

  Background:
    Given the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: View the component libraries list
    Given the user has imported 2 component libraries: "UI Kit" (ready) and "Icons" (importing)
    When the user navigates to /libraries
    Then the page should display 2 library cards
    And "UI Kit" should show its name, status, and component count
    And "Icons" should show its current import status

  @happy-path
  Scenario: Navigate to library detail page
    Given a ready component library "UI Kit" exists
    When the user clicks on the "UI Kit" library card
    Then the user should be navigated to /libraries/:id
    And the page should display the library name "UI Kit"
    And all component sets and standalone components should be listed

  @happy-path
  Scenario: Library detail shows sync progress for non-ready libraries
    Given a component library exists with status "importing"
    When the user views the library detail page
    Then a status badge should show "importing"
    And a progress bar should indicate the current sync step

  @happy-path
  Scenario: Import a new library from the libraries page
    When the user enters a Figma URL in the import input on the libraries page
    And clicks the import button
    Then a new component library should be created
    And a sync job should be triggered
    And the libraries list should refresh

  @happy-path
  Scenario: Component preview page renders all components
    Given a component library "UI Kit" has 5 component sets and 3 standalone components
    When the preview page is loaded at /api/component-libraries/:id/preview
    Then all 8 components should be rendered in a grid layout
    And each card should show the component name, type badge, and live React preview
    And component sets should show their variants list
    And vector components should display their SVG icons

  # --- ComponentDetail Layout ---

  @happy-path
  Scenario: ComponentDetail view structure
    Given the user is viewing a component "Button" in any context (modal, settings, or library detail)
    Then the component name "Button" should be displayed at the top (16px, bold)
    And below the name: "link to figma" (clickable, opens Figma component in new tab)
    And next to or below: "sync with figma" (clickable, triggers re-import of this component)
    And a type badge should show "Component Set" or "Component" (pill-shaped, small)
    And a status badge should show the import status ("ready", "importing", or "no code") with color coding

  @happy-path
  Scenario: ComponentDetail shows interactive props with type-dependent controls
    Given a component "Button" has variant props:
      | prop_name | type    | values                      |
      | Size      | VARIANT | sm, md, lg                  |
      | State     | VARIANT | default, hover, pressed     |
      | Label     | TEXT    |                             |
      | Disabled  | BOOLEAN |                             |
    When the user views the Button component detail
    Then a "props" section should be present (label in primary text, 14px)
    And "Size" should have a dropdown/select with options "sm", "md", "lg"
    And "State" should have a dropdown/select with options "default", "hover", "pressed"
    And "Label" should have a text input field
    And "Disabled" should have a checkbox

  @happy-path
  Scenario: Changing props updates the live preview in real-time
    Given the user is viewing a component "Button" with a live preview iframe
    When the user changes the "State" prop from "default" to "hover"
    Then a postMessage with updated JSX should be sent to the preview iframe
    And the iframe should re-render the component with the "hover" state
    And the re-render should happen without any explicit submit action

  @happy-path
  Scenario: ComponentDetail shows live preview iframe
    Given the user is viewing a component "Button"
    Then a "live preview" section should show a bordered iframe (1px solid --accent-border)
    And the iframe should point to the component library renderer URL
    And the iframe should render the component with the current prop values
    And the iframe should take full width of the content area (~200-300px height)

  @happy-path
  Scenario: ComponentDetail shows React code in read-only editor
    Given a component "Button" has generated React code
    When the user expands the "React Code" section
    Then a CodeMirror editor should display the component's React source code
    And the editor should be read-only
    And it should use monospace font with JSX syntax highlighting

  @happy-path
  Scenario: ComponentDetail shows configuration (root and children)
    Given a component "Page" is marked as root with allowed_children ["Title", "Button"]
    When the user views the component detail
    And expands the "Configuration" section
    Then a "Root" row should show "yes" badge (read-only)
    And an "Allowed children" row should list "Title" and "Button" (read-only)
    And these values are set by Figma conventions and cannot be edited in the browser

  @happy-path
  Scenario: Component detail modal shows visual diff
    Given a component has Figma and React screenshots and a diff image
    When the user opens the component detail modal
    Then the visual diff overlay should show three panels: Figma, React, and Diff
    And the match percentage badge should be displayed

  @happy-path
  Scenario: Update component library visibility
    Given a component library "UI Kit" exists with is_public false
    When the user sends PATCH /api/component-libraries/:id with is_public true
    Then the library should be publicly accessible to other users

  @edge-case
  Scenario: Component with no variants still displays correctly
    Given a standalone component "Divider" exists with no variants
    When the user views the component detail
    Then the props section should be empty or hidden
    And the preview should render the component with default props

  @edge-case
  Scenario: Preview page handles components without React code gracefully
    Given a component exists without compiled React code
    When the preview page loads
    Then a "Component not found" error should be shown in that component's preview area
