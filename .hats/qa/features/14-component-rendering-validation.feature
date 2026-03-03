@mode:serial
@timeout:1200000
Feature: Component Rendering Validation
  Validates that every imported component renders correctly in the
  ComponentDetail preview iframe with all prop combinations.
  This is the primary quality assurance feature: it exercises the entire
  Figma-to-React pipeline by checking WHAT actually renders in the iframe,
  not just that something is visible.

  Each component is tested individually:
  - Default render: iframe #root must not be empty, no red error text
  - VARIANT props: each option must produce different innerHTML from the baseline
    (first option). Components carry BEM variant classes on their root element
    (e.g. Button__size_m) that ensure a DOM difference even for styling-only variants.
  - BOOLEAN props: toggling must produce different innerHTML before vs after.
  - TEXT props: a unique sentinel string is filled in and must appear verbatim
    in #root textContent.

  @critical
  Scenario: Ensure Figma library is imported for rendering tests
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Render" is imported from Cubes
    Then the design system "QA Render" should appear in the library selector
    And there are no console errors

  @critical
  Scenario: Every component renders with default props without errors
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Render"
    Then I validate that every component renders with default props
    And there are no console errors

  @critical
  Scenario: Every component renders correctly with all prop variations
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Render"
    Then I validate every component with all prop combinations
    And there are no console errors

  Scenario: Text props display their values in the rendered output
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Render"
    Then I validate that text props produce visible output in the iframe
    And there are no console errors

  Scenario: Variant prop changes produce visually different renders
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Render"
    Then I validate that variant changes produce different HTML output
    And there are no console errors
