@api @visual-diff
Feature: Visual Diff API
  After component import and React code generation, the system compares
  Figma screenshots with React-rendered screenshots to measure fidelity.
  Results stored as match_percent on component/variant records.

  Scenario: Visual diff for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/visual_diff"
    Then the API response status should be 404

  Scenario: Diff image not available returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/diff_image"
    Then the API response status should be 404

  Scenario: Figma screenshot for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/screenshots/figma"
    Then the API response status should be 404

  Scenario: React screenshot for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/components/999999/screenshots/react"
    Then the API response status should be 404

  Scenario: Invalid screenshot type returns 400
    Given the user is logged in as alice
    And I have a component from a ready library
    When I send an authenticated GET to the component screenshots with type "invalid"
    Then the API response status should be 400

  Scenario: Visual diff for existing component returns data
    Given the user is logged in as alice
    And I have a component from a ready library
    When I send an authenticated GET to the component visual diff
    Then the API response status should be 200
    And the API response body should contain field "match_percent"
