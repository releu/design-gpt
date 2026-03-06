@component-rendering @validation
Feature: Component Rendering Validation
  Validates that every imported component renders correctly in the
  component detail PREVIEW with all PROP combinations. This ensures
  the Figma-to-React pipeline produces renderable components.

  Background:
    Given a DESIGN_SYSTEM has been fully imported
    And the user is logged in as "alice@example.com"

  Scenario: Every component renders with default PROPs
    Given the DESIGN_SYSTEM contains COMPONENT_SETs and standalone COMPONENTs
    When each component is rendered in the PREVIEW with default PROP values
    Then every component renders without errors
    And the PREVIEW is not empty for any component

  Scenario: COMPONENT renders correctly when VARIANT PROP is changed
    Given TITLE has a VARIANT PROP "size" with values ["m", "l"]
    When the component is rendered with size="l"
    Then the PREVIEW shows the large VARIANT
    And there are no rendering errors

  Scenario: COMPONENT renders correctly with text PROP
    Given TITLE has a text PROP "text"
    When the component is rendered with text="Hello World"
    Then the PREVIEW displays "Hello World"
    And there are no rendering errors

  Scenario: COMPONENT renders correctly with boolean PROP
    Given TITLE has a boolean PROP "marker"
    When the component is rendered with marker enabled
    Then the PREVIEW reflects the marker state
    And there are no rendering errors

  Scenario: VECTOR components display as SVG
    Given ICON_SINGLE is a VECTOR component
    When the component is viewed in the component detail
    Then an SVG image is displayed instead of a React PREVIEW
