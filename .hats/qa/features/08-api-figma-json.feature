@api @figma-json
Feature: Figma JSON Inspection API
  Developers can inspect raw Figma JSON data for components and component sets.
  No auth required. Serves from Component#figma_json and ComponentSet default variant.

  Scenario: Figma JSON for nonexistent component returns 404
    When I send a plain GET to "/api/components/999999/figma_json"
    Then the API response status should be 404

  Scenario: Figma JSON for nonexistent component set returns 404
    When I send a plain GET to "/api/component-sets/999999/figma_json"
    Then the API response status should be 404

  Scenario: Figma JSON for existing component returns data
    Given I have a component id from a ready library
    When I send a plain GET to the component figma json
    Then the API response status should be 200
    And the API response body should contain field "id"
    And the API response body should contain field "name"

  Scenario: Figma JSON for existing component set returns data
    Given I have a component set id from a ready library
    When I send a plain GET to the component set figma json
    Then the API response status should be 200
    And the API response body should contain field "id"
