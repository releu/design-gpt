@figma-json
Feature: Figma JSON Inspection
  Developers can inspect the raw Figma JSON data for any component or
  component set. This helps debug import issues and understand the
  Figma component structure.
  Technical: No auth required. Serves from Component#figma_json and
  ComponentSet default variant figma_json.

  @happy-path
  Scenario: View Figma JSON for a standalone component
    Given a component exists with stored Figma JSON data
    When the user sends GET /api/components/:id/figma_json
    Then the response should include id, node_id, name, and figma_json fields
    And figma_json should contain the raw Figma API response for that component

  @happy-path
  Scenario: View Figma JSON for a component set (default variant)
    Given a component set exists with a default variant that has Figma JSON
    When the user sends GET /api/component-sets/:id/figma_json
    Then the response should include the default variant's figma_json

  @happy-path
  Scenario: Figma JSON is lazy-loaded in the preview page
    Given the component preview page is loaded
    When the user clicks on the "Figma JSON" details section for a component
    Then the Figma JSON should be fetched asynchronously
    And displayed in a formatted code block

  @edge-case
  Scenario: Component without Figma JSON
    Given a component exists with no figma_json stored
    When the user sends GET /api/components/:id/figma_json
    Then figma_json should be null in the response
