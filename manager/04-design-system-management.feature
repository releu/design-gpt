@design-system
Feature: Design System Management
  Users create design systems by grouping one or more component libraries under a name.
  Design systems serve as the component palette for AI design generation.
  Technical: DesignSystem has_many ComponentLibraries through DesignSystemLibraries.
  Configuration (is_root, allowed_children) is set automatically from Figma conventions.

  Background:
    Given the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: Create a new design system via the modal
    Given the user has imported a Figma component library that is "ready"
    When the user clicks "New design system" on the home page
    Then the design system modal should appear
    When the user adds a Figma URL and clicks "Import"
    Then the import progress bar should be visible
    When the import completes
    Then the component browser should appear with a left menu listing all components
    And the right panel should show the "Overview" with a name input field
    When the user enters "My Design System" as the name
    And clicks "Save"
    Then a DesignSystem should be created with name "My Design System"
    And the DesignSystem should be linked to the imported component libraries
    And the modal should close
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
  Scenario: Browse an existing design system
    Given the user has a design system "Example" with components
    When the user clicks "Browse" next to the "Example" design system
    Then the design system modal should open showing all components
    And the Overview should display the design system name and library file counts
    And each component should be selectable from the left menu

  @happy-path
  Scenario: View component detail in the browser
    Given the design system modal is open with imported components
    When the user clicks on a component "Button" in the left menu
    Then the right panel should show the ComponentDetail view
    And the component name "Button" should be displayed
    And the component type badge should show "Component Set"
    And the props section should list all available props with their types
    And the preview iframe should render the component with default props

  @happy-path
  Scenario: Interactive prop editing updates preview
    Given the user is viewing a component "Button" with a VARIANT prop "State" having values ["default", "hover", "pressed"]
    When the user selects "hover" from the "State" dropdown
    Then the preview iframe should re-render the component with the "hover" state
    And the generated JSX should include the updated prop value

  @happy-path
  Scenario: View AI Schema shows component tree reachable from root
    Given the design system modal is open with a root component "Page" that allows children ["Title", "Text"]
    When the user clicks "AI Schema" in the left menu
    Then the AI Schema view should display a tree starting from "Page"
    And "Title" and "Text" should appear as allowed children under "Page"
    And the subtitle should explain "Components reachable from root"

  @happy-path
  Scenario: Update component library from Figma
    Given the design system modal is open with an imported library
    When the user clicks "Update from Figma" in the Overview
    Then the modal should show the importing progress
    And when the sync completes, the component browser should refresh with updated components

  @happy-path
  Scenario: Component configuration is read-only (set by Figma conventions)
    Given the user is viewing a component "Page" that is marked as root
    And "Page" has allowed_children ["Title", "Button"]
    When the user opens the Configuration section
    Then the root badge should show "yes"
    And the allowed children should list "Title" and "Button"
    And these fields should not be editable in the UI

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
