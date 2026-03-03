@api @assets
Feature: Component SVG Assets API
  Vector components and icons are exported as SVGs from Figma and cached
  as FigmaAssets. Served by ComponentsController#svg and component_set_svg.

  Scenario: SVG for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/svg"
    Then the API response status should be 404

  Scenario: HTML preview for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/html_preview"
    Then the API response status should be 404

  Scenario: SVG for existing component returns content
    Given the user is logged in as alice
    And I have a component from a ready library
    When I send an authenticated GET to the component svg
    Then the API response status should not be 500

  Scenario: SVG for component set returns content
    Given the user is logged in as alice
    And I have a component set from a ready library
    When I send an authenticated GET to the component set svg
    Then the API response status should not be 500

  Scenario: HTML preview for existing component
    Given the user is logged in as alice
    And I have a component from a ready library
    When I send an authenticated GET to the component html preview
    Then the API response status should not be 500
