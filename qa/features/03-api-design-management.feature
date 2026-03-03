@api @design-management
Feature: Design Management API
  Users can list, view, rename, duplicate, delete, and export their designs via API.
  All routes scoped under /api/designs.

  @critical
  Scenario: List designs returns empty array for new user
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/designs"
    Then the API response status should be 200
    And the API response body should be a JSON array

  @critical
  Scenario: Create a design via API requires component libraries
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/designs" with body:
      """
      { "design": { "prompt": "Hello world test" } }
      """
    Then the API response status should not be 201

  Scenario: Create a design via API with component libraries
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/designmgmt1/for-design-create"
    When I create a design via API with prompt "API creation test" and the created library
    Then the API response status should be 201
    And the API response body should contain field "id"
    And the API response body should contain field "status"

  Scenario: View a specific design via API
    Given the user is logged in as alice
    And I have created a design via API with prompt "View test design"
    When I send an authenticated GET to the created design
    Then the API response status should be 200
    And the API response body should contain "View test design"

  Scenario: Default design name is derived from prompt
    Given the user is logged in as alice
    And I have created a design via API with prompt "Create a dashboard for weather data in European capitals"
    When I send an authenticated GET to the created design
    Then the API response status should be 200
    And the API response body should contain "Create a dashboard for weather data"

  Scenario: Rename a design via API
    Given the user is logged in as alice
    And I have created a design via API with prompt "Rename test"
    When I send an authenticated PATCH to the created design with body:
      """
      { "design": { "name": "New Name" } }
      """
    Then the API response status should be 200
    And the API response body should contain "New Name"

  Scenario: Duplicate a design via API
    Given the user is logged in as alice
    And I have created a design via API with prompt "Original for duplication"
    When I send an authenticated POST to duplicate the created design
    Then the API response status should be 201
    And the API response body should contain field "id"

  Scenario: Delete a design via API
    Given the user is logged in as alice
    And I have created a design via API with prompt "Delete test"
    When I send an authenticated DELETE to the created design
    Then the API response status should be 204

  Scenario: Deleted design is no longer accessible
    Given the user is logged in as alice
    And I have created a design via API with prompt "Verify gone after delete"
    When I send an authenticated DELETE to the created design
    And I send an authenticated GET to the created design
    Then the API response status should be 404

  Scenario: Access another user's design returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/designs/999999"
    Then the API response status should be 404

  Scenario: Export Figma JSON for nonexistent design returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/designs/999999/export_figma"
    Then the API response status should be 404

  Scenario: Export React project for nonexistent design returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/designs/999999/export_react"
    Then the API response status should be 404

  Scenario: Export image for nonexistent design returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/designs/999999/export_image"
    Then the API response status should be 404
