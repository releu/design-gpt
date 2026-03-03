@mode:serial
@timeout:600000
Feature: Preview Rendering
  The preview component renders generated JSX inside an iframe using a
  renderer page that includes React, ReactDOM, Babel, and all compiled
  component code. Communication happens via postMessage.

  Scenario: Setup library for renderer tests
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Preview" is imported from Cubes
    Then the design system "QA Preview" should appear in the library selector
    And there are no console errors

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

  Scenario: Renderer serves without authentication
    Given the QA library renderer URL is known
    When I load the renderer page without auth
    Then the renderer page should load successfully
    And there are no console errors

  Scenario: Renderer handles missing component gracefully
    Given the QA library renderer URL is known
    When I load the renderer page directly
    And I wait for the renderer ready message
    And I send JSX referencing nonexistent component "FooBarBaz"
    Then the renderer should show a rendering error
    And the error should not crash the renderer
    And there are no console errors

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
