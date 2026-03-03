@component-rendering @validation
Feature: Component Rendering Validation
  Validates that every imported component renders correctly in the
  ComponentDetail preview iframe with all prop combinations.
  This is a quality assurance feature ensuring the Figma-to-React
  pipeline produces renderable components.
  Technical: Each component's props (VARIANT, TEXT, BOOLEAN) are exercised.
  The preview iframe receives JSX via postMessage and must render without
  JS console errors.

  Background:
    Given a Figma component library has been fully imported and is "ready"
    And the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: Every component renders with default props
    Given the library contains N component sets and M standalone components
    When each component is rendered in the preview iframe with default prop values
    Then every component should render without JavaScript errors in the console
    And the iframe #root should not be empty for any component

  @happy-path
  Scenario: Component renders correctly when variant prop is changed
    Given a component "Button" has a VARIANT prop "State" with values ["default", "hover", "pressed"]
    When the component is rendered with State="hover"
    Then the preview should update to show the hover variant
    And there should be no console errors

  @happy-path
  Scenario: Component renders correctly with text prop
    Given a component "Title" has a TEXT prop "text"
    When the component is rendered with text="Hello World"
    Then the preview should display "Hello World"
    And there should be no console errors

  @happy-path
  Scenario: Component renders correctly with boolean prop
    Given a component "Toggle" has a BOOLEAN prop "isActive"
    When the component is rendered with isActive={true}
    Then the preview should reflect the active state
    And there should be no console errors

  @edge-case
  Scenario: Vector/icon components display as SVG
    Given a component set is marked as vector
    When the component is viewed in the component detail
    Then an SVG image should be displayed instead of a React preview
