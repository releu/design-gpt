@api @ai-pipeline
Feature: AI Task Pipeline API
  The AI task system manages requests to the OpenAI API for design generation.
  Tasks are created by DesignGenerator, processed by AiRequestJob.
  External workers can poll via GET /api/tasks/next with TASKS_TOKEN.

  Scenario: Task API rejects unauthorized workers
    When I send a plain GET to "/api/tasks/next"
    Then the API response status should be 401

  Scenario: Design systems API requires authentication
    When I send an unauthenticated GET to "/api/design-systems"
    Then the API response status should be 401

  Scenario: List design systems for authenticated user
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/design-systems"
    Then the API response status should be 200
    And the API response body should be a JSON array

  Scenario: Create a design system via API
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/dspipeline1/ds-create-test"
    When I create a design system via API with name "Pipeline DS" and the created library
    Then the API response status should be 201
    And the API response body should contain "Pipeline DS"

  Scenario: Task show endpoint for nonexistent task returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/tasks/999999"
    Then the API response status should be 404

  Scenario: Design generation creates a task when called via API
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/dspipeline2/ds-gen-test"
    And I create a design system via API with name "Gen Pipeline DS" and the created library
    When I create a design via API with prompt "Test task creation" and the created library
    Then the API response status should be 201
    And the API response body should contain field "id"
