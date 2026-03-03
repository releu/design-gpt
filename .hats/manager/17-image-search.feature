@images
Feature: Image Search
  The application provides an image search endpoint powered by Yandex Images.
  This can be used to find reference images during the design process.
  Technical: GET /api/images?q=query, uses YandexImages service.

  @happy-path
  Scenario: Search for images
    When the user sends GET /api/images with query "mountain landscape"
    Then the response should contain image search results from Yandex
    And the results should be returned as JSON

  @edge-case
  Scenario: Empty search query
    When the user sends GET /api/images without a query parameter
    Then the response should handle the empty query gracefully
