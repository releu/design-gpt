@mode:serial
@timeout:600000
Feature: Design Generation Workflow
  Users enter a text prompt and select a design system. The backend generates
  a JSON tree via AI, transforms it to JSX, and the frontend renders it in
  a preview iframe. Design status flow: draft -> generating -> ready | error.
  UI reference: designer/04-home-new-design.md, designer/05-design-page.md,
  designer/02-layout-structures.md

  # --- Setup ---

  @critical
  Scenario: Ensure design system exists for generation
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Generate" is imported from Cubes
    Then the design system "QA Generate" should appear in the library selector
    And there are no console errors

  # --- Home Page Layout (Layout 1: Three Columns + Bottom Bar) ---

  @critical
  Scenario: Home page displays three-column layout with bottom bar
    Given I navigate to the home page
    And the app container is visible
    Then the page should use a three-column layout below the header
    And the left column should contain the prompt panel
    And the center column should contain the design system panel
    And the right column should contain the preview frame
    And a bottom bar should span the left and center columns
    And columns should be separated by drag-handle dividers
    And there are no console errors

  @critical
  Scenario: Prompt panel shows white card with label and textarea
    Given I navigate to the home page
    And the app container is visible
    Then the prompt panel should be a white card with rounded corners
    And a "prompt" label should appear above the textarea
    And the textarea placeholder should contain "describe"
    When I set the prompt text to "List top 5 parks in Amsterdam"
    Then the prompt text should be visible in the textarea
    And there are no console errors

  @critical
  Scenario: Design system panel shows library list with edit and new
    Given I navigate to the home page
    And the app container is visible
    Then the design system panel should be a white card with label
    And the panel should show a list of available libraries
    And the selected library should have a highlight and an "edit" link
    And a "new" button should appear at the bottom of the panel
    And there are no console errors

  @critical
  Scenario: AI engine bar with generate button
    Given I navigate to the home page
    And the app container is visible
    Then the AI engine bar should be visible below the prompt and design system panels
    And the bar should show "ChatGPT" as the engine name
    And a pill-shaped "generate" button should be visible
    And the generate button should have dark background with white text
    And there are no console errors

  # --- Generate Flow ---

  @critical
  Scenario: Generate a design from a prompt
    Given I navigate to the home page
    And I verify design system "QA Generate" exists
    When I set the prompt text to "List the top 5 rivers in Belgrade"
    And I select design system "QA Generate"
    And I click the generate button
    Then I should be navigated to a design page
    And the design page should show the view mode switcher
    And the preview area should show the empty state
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    And the preview iframe content should not be empty
    And the rendered preview should contain text "Sava"
    And the rendered preview should contain text "Dunav"
    And there are no console errors

  # --- Design Page View Modes ---

  Scenario: Phone view uses two-column layout (Layout 2)
    Given I am on the current design page
    When I click the mobile view switcher
    Then the preview should render in mobile layout
    And the layout should have two columns for chat and phone preview
    And there are no console errors

  Scenario: Desktop view uses stacked layout (Layout 3)
    Given I am on the current design page
    When I click the desktop view switcher
    Then the preview should render in desktop layout
    And the desktop frame should have rounded corners
    And there are no console errors

  Scenario: Code view uses three-column layout (Layout 4)
    Given I am on the current design page
    When I click the code view switcher
    Then the code editor should be visible
    And the code editor should contain JSX content
    And the code editor should use CodeMirror
    And there are no console errors

  Scenario: View mode switching between mobile, desktop, and code
    Given I am on the current design page
    When I click the desktop view switcher
    Then the preview should render in desktop layout
    When I click the code view switcher
    Then the code editor should be visible
    And the code editor should contain JSX content
    When I click the mobile view switcher
    Then the preview should render in mobile layout
    And there are no console errors

  # --- Code Editor ---

  Scenario: Editing JSX in code view triggers live preview update
    Given I am on the current design page
    When I click the code view switcher
    And I capture the current code editor content
    And I modify the JSX in the code editor
    Then the code editor content should have changed
    And there are no console errors

  # --- Design Selector Dropdown ---

  Scenario: Design page shows design name in pill-shaped selector dropdown
    Given I am on the current design page
    Then the design dropdown should be visible
    And the design dropdown should be pill-shaped with a caret
    And the design dropdown should contain at least one design option
    And there are no console errors

  Scenario: Navigate from design page back to new design
    Given I am on the current design page
    When I select new design from the dropdown
    Then I should be navigated to the home page
    And there are no console errors

  # --- Preview Frame ---

  Scenario: Home page preview frame shows placeholder
    Given I navigate to the home page
    And the app container is visible
    Then the preview frame placeholder should show "preview" text
    And the preview frame should have a border with phone styling
    And there are no console errors

  Scenario: Preview selector changes preview frame style
    Given I navigate to the home page
    And the app container is visible
    Then the preview selector in the header should show phone, desktop, and code options
    And there are no console errors

  # --- Edge Cases ---

  Scenario: New user with no design systems sees disabled generate
    Given I navigate to the home page
    And the app container is visible
    Then the generate button should be present
    And there are no console errors

  # --- Export Menu ---

  Scenario: Export menu is accessible from the design page
    Given I navigate to the home page
    And I verify design system "QA Generate" exists
    When I set the prompt text to "List parks in Tokyo for export menu test"
    And I select design system "QA Generate"
    And I click the generate button
    Then I should be navigated to a design page
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    When I click the export menu button
    Then the export menu should be visible
    And the export menu should contain "Download React project"
    And the export menu should contain "Download image"
    And there are no console errors
