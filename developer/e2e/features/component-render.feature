@mode:serial
@timeout:1200000
Feature: Component Rendering Validation

  Validates that every component imported from Figma renders correctly
  in the ComponentDetail preview iframe with all prop combinations.

  Scenario: Ensure Figma library is imported
    Given I navigate to the home page
    And the app container is visible
    When I ensure the Cubes library is imported as "Cubes"
    Then a design system should appear in the library selector

  Scenario: Every component renders correctly with all prop values
    Given I navigate to the home page
    And the app container is visible
    When I open the design system "Cubes"
    Then I validate rendering of every component in the browser
    And there are no console errors
