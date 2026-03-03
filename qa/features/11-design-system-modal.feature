@mode:serial
@timeout:600000
Feature: Design System Creation via Modal
  Users create design systems by importing Figma component libraries through a modal.
  The modal has 3 phases: add URLs, importing, done (browser).
  Configuration (is_root, allowed_children) is read-only, set by Figma conventions.

  @critical
  Scenario: Import Figma file and create a design system
    Given I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    When I add the Cubes Figma URL
    Then the Figma URL should appear in the pending list
    When I click the import button
    Then the component browser should be visible within 5 minutes
    And the component browser menu should list component names
    When I enter the design system name "QA Cubes"
    And I click "Save" in the modal
    Then the design system modal should close
    And the design system "QA Cubes" should appear in the library selector
    And there are no console errors

  Scenario: Browse components in the design system shows details
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    Then the component browser should be visible
    And the Overview panel should show the design system name
    When I click the first component in the menu
    Then the component detail panel should show the component name
    And the component detail should show the type badge
    And the component detail should show the status badge
    And there are no console errors

  Scenario: Component configuration is read-only from Figma conventions
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I find a root component in the menu
    Then the Configuration section should show root badge "yes"
    And the allowed children list should not be empty
    And there are no console errors

  Scenario: AI Schema view shows component tree
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Cubes"
    And I click "AI Schema" in the component browser menu
    Then the AI Schema view should be visible
    And there are no console errors
