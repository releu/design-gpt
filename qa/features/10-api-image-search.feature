@api @images
Feature: Image Search API
  The application provides an image search endpoint powered by Yandex Images.
  GET /api/images?q=query returns image search results as JSON.

  Scenario: Image search endpoint exists
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/images?q=mountain"
    Then the API response status should not be 404

  Scenario: Empty search query is handled gracefully
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/images"
    Then the API response status should not be 500

  Scenario: Image search returns JSON results
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/images?q=landscape"
    Then the API response status should not be 404
    And the response content type should be JSON
