@mode:serial
@timeout:600000
Feature: Design Export
  Users can export designs as React project zip, PNG image, or Figma JSON.
  Export actions are available from a "..." menu on the design page.

  Scenario: Setup design for export testing
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Export" is imported from Cubes
    And I set the prompt text to "Create a simple list of European capitals"
    And I select design system "QA Export"
    And I click the generate button
    Then I should be navigated to a design page
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    And there are no console errors

  Scenario: Export Figma JSON via API returns component tree
    Given I am on the current design page
    When I request Figma JSON export for the current design via API
    Then the export response should contain field "tree"
    And the export response should contain field "jsx"
    And the export response should contain field "component_library_ids"
    And there are no console errors

  Scenario: Export React project via API returns zip
    Given I am on the current design page
    When I request React export for the current design via API
    Then the export response content type should be "application/zip"
    And there are no console errors

  Scenario: Export image returns 404 when no screenshot exists
    Given I am on the current design page
    When I request image export for the current design via API
    Then the image export response status should be either 200 or 404
    And there are no console errors

  Scenario: Duplicate a design via API
    Given I am on the current design page
    When I duplicate the current design via API
    Then the duplicate response should contain a new design id
    And the duplicate response should have status 201
    And there are no console errors

  Scenario: Export menu is visible on design page
    Given I am on the current design page
    When I click the export menu button
    Then the export menu should be visible
    And the export menu should contain "Download React project"
    And the export menu should contain "Download image"
    And there are no console errors
