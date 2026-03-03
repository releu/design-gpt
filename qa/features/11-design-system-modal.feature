@mode:serial
@timeout:600000
Feature: Design System Modal
  Users create and manage design systems through a full-screen modal overlay.
  The modal has a two-pane layout: left navigation sidebar and right content area.
  Configuration (is_root, allowed_children) is read-only, set by Figma conventions.
  UI reference: designer/06-design-system-modal.md

  # --- Modal Overlay Structure ---

  @critical
  Scenario: Import Figma file and create a design system
    Given I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    When I add the Cubes Figma URL
    Then the Figma URL should appear in the pending list
    When I click the import button
    Then the component browser should be visible within 10 minutes
    And the component browser menu should list component names
    When I enter the design system name "QA Cubes"
    And I click "Save" in the modal
    Then the design system modal should close
    And the design system "QA Cubes" should appear in the library selector
    And there are no console errors

  Scenario: Modal opens as full-screen overlay with close button
    Given I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    And the modal overlay should cover the full screen
    And a close button should be visible in the top-left of the overlay
    And the modal card should be centered with rounded corners
    And there are no console errors

  Scenario: Modal has two-pane layout with sidebar and content area
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    Then the modal should have a left navigation sidebar
    And the modal should have a right content area
    And the left sidebar should show a "general" section with "Overview" item
    And there are no console errors

  # --- Overview Pane ---

  Scenario: Overview pane shows design system details and file list
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    Then the Overview panel should show the design system name
    And the Overview should display file names with component counts
    And there are no console errors

  Scenario: Browse components in the left sidebar organized by Figma file
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    Then the left sidebar should show component names grouped under Figma file headers
    And file names should appear as gray section headers
    And component names should be indented below their file header
    And there are no console errors

  # --- Component Detail ---

  Scenario: Component detail shows name, type badge, and status badge
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click the first component in the menu
    Then the component detail panel should show the component name
    And the component detail should show the type badge
    And the component detail should show the status badge
    And there are no console errors

  Scenario: Component detail shows Figma link and sync action
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click the first component in the menu
    Then the component detail should show a "link to figma" link
    And the component detail should show a "sync with figma" action
    And there are no console errors

  @critical
  Scenario: Component detail shows interactive props with type-dependent controls
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click a component that has variant props
    Then the Props section should list available props
    And variant props should have dropdown selects
    And there are no console errors

  Scenario: Changing props updates the live preview in real-time
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click a component that has variant props
    And I capture the current preview content
    And I change the first variant prop to a different value
    Then the preview iframe content should differ from the captured content
    And there are no console errors

  Scenario: Component detail shows live preview iframe
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click a component that has variant props
    Then the live preview iframe should be visible with a border
    And the preview iframe should render the component
    And there are no console errors

  Scenario: Component detail shows React code in read-only editor
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click a component that has React code
    And I expand the React Code section
    Then the code section should display React source code
    And there are no console errors

  # --- Configuration ---

  Scenario: Component configuration is read-only from Figma conventions
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I find a root component in the menu
    Then the Configuration section should show root badge "yes"
    And the allowed children list should not be empty
    And there are no console errors

  # --- AI Schema ---

  Scenario: AI Schema view shows component tree
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click "AI Schema" in the component browser menu
    Then the AI Schema view should be visible
    And there are no console errors

  # --- Close Behavior ---

  Scenario: Close modal via close button
    Given I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    When I click the modal close button
    Then the design system modal should close
    And there are no console errors

  Scenario: Close modal by clicking overlay background
    Given I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    When I click the overlay background outside the modal card
    Then the design system modal should close
    And there are no console errors
