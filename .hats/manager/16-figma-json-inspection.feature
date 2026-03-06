@figma-json
Feature: Figma JSON Inspection
  Users can inspect the raw Figma JSON data for any COMPONENT or
  COMPONENT_SET. This helps debug import issues and understand the
  Figma component structure.

  Scenario: View Figma JSON for a standalone COMPONENT
    Given a COMPONENT exists with stored Figma JSON data
    When the user inspects the raw Figma data for the COMPONENT
    Then the COMPONENT's name, node ID, and full Figma JSON are shown

  Scenario: View Figma JSON for a COMPONENT_SET (default VARIANT)
    Given a COMPONENT_SET exists with a default VARIANT that has Figma JSON
    When the user inspects the raw Figma data for the COMPONENT_SET
    Then the default VARIANT's Figma JSON is shown

  Scenario: Figma JSON is lazy-loaded in the PREVIEW page
    Given the component PREVIEW page is loaded
    When the user clicks on the "Figma JSON" section for a COMPONENT
    Then the Figma JSON is fetched on demand
    And displayed in a formatted code block

  Scenario: COMPONENT without Figma JSON
    Given a COMPONENT exists with no Figma JSON stored
    When the user inspects the raw Figma data
    Then no JSON data is shown
