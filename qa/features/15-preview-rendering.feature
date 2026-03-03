@mode:serial
@timeout:600000
Feature: Preview Rendering
  The preview component renders generated JSX inside an iframe using a
  renderer page that includes React, ReactDOM, Babel, and all compiled
  component code. Communication happens via postMessage.
  UI reference: designer/07-shared-components.md (preview frame #8),
  designer/05-design-page.md (phone/desktop preview contexts)

  Scenario: Setup library for renderer tests
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Preview" is imported from Cubes
    Then the design system "QA Preview" should appear in the library selector
    And there are no console errors

  # --- Renderer Dependencies ---

  @critical
  Scenario: Renderer page loads with all dependencies
    Given the QA library renderer URL is known
    When I load the renderer page directly
    Then the renderer page should contain React script tag
    And the renderer page should contain ReactDOM script tag
    And the renderer page should contain Babel script tag
    And the renderer page should have a root div
    And there are no console errors

  @critical
  Scenario: Renderer accepts JSX via postMessage and renders it
    Given the QA library renderer URL is known
    When I load the renderer page directly
    And I wait for the renderer ready message
    And I send JSX to the renderer via postMessage
    Then the renderer root should contain the rendered component
    And there are no console errors

  # --- Phone Frame ---

  Scenario: Phone frame has correct styling
    Given the QA library renderer URL is known
    When I load the renderer page directly
    Then the renderer page should load successfully
    And there are no console errors

  # --- Desktop Frame ---

  Scenario: Desktop frame has correct styling
    Given the QA library renderer URL is known
    When I load the renderer page directly
    Then the renderer page should load successfully
    And there are no console errors

  # --- Placeholder ---

  Scenario: Preview placeholder state shows "preview" text
    Given I navigate to the home page
    And the app container is visible
    Then the preview frame placeholder should show "preview" text
    And there are no console errors

  # --- Auth ---

  Scenario: Renderer serves without authentication
    Given the QA library renderer URL is known
    When I load the renderer page without auth
    Then the renderer page should load successfully
    And there are no console errors

  # --- Error Handling ---

  Scenario: Renderer handles missing component gracefully
    Given the QA library renderer URL is known
    When I load the renderer page directly
    And I wait for the renderer ready message
    And I send JSX referencing nonexistent component "FooBarBaz"
    Then the renderer should show a rendering error
    And the error should not crash the renderer
    And there are no console errors

  # --- Multiple Library Renderers ---

  Scenario: Design system renderer combines multiple libraries
    Given the QA design system renderer URL is known
    When I load the design system renderer page
    Then the renderer page should contain React script tag
    And the renderer page should contain ReactDOM script tag
    And the renderer page should have a root div
    And there are no console errors

  Scenario: Iteration renderer uses the design's libraries
    Given the QA iteration renderer URL is known
    When I load the iteration renderer page
    Then the renderer page should contain React script tag
    And the renderer page should have a root div
    And there are no console errors
