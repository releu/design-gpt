Feature: Image Workflow
  The image render endpoint accepts a prompt, searches for an image via
  Yandex, caches the result, and redirects to the image URL. Design
  previews render image components as divs with CSS background-image.

  Scenario: Image render endpoint returns proxied image bytes
    When the user requests GET /api/images/render?prompt=modern+office
    Then the response status is 200
    And the Content-Type is image/*
    And the Access-Control-Allow-Origin header is *

  Scenario: Blank prompt returns 400
    When the user requests GET /api/images/render?prompt=
    Then the response status is 400

  Scenario: Cache returns same image for repeated queries
    When the user requests GET /api/images/render?prompt=sunset+beach
    And the user requests GET /api/images/render?prompt=sunset+beach again
    Then both responses return identical image bytes

  Scenario: Image search requires authentication
    When an unauthenticated user requests GET /api/images?q=office
    Then the response status is 401

  Scenario: Design preview renders image component with background-image
    Given the user has a design with an image component
    When the design preview loads
    Then the preview contains a div with backgroundImage style
    And the preview does not contain an img tag for the image component
