@api @figma-import
Feature: Figma Component Library Import API
  Users import component libraries from Figma files via the API.
  The system extracts component sets, variants, standalone components, and SVG assets.
  Status flow: pending -> discovering -> importing -> converting -> comparing -> ready | error.

  @critical
  Scenario: Create a component library from a Figma URL
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/component-libraries" with body:
      """
      { "url": "https://www.figma.com/design/abc123/my-design-system" }
      """
    Then the API response status should be 201
    And the API response body should contain field "id"

  Scenario: Created library has pending status
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/component-libraries" with body:
      """
      { "url": "https://www.figma.com/design/pendingtest1/pending-check" }
      """
    Then the API response status should be 201
    And the API response body should contain "pending"

  Scenario: Created library extracts figma file key from URL
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/component-libraries" with body:
      """
      { "url": "https://www.figma.com/design/extractKey99/file-key-test" }
      """
    Then the API response status should be 201
    And the API response body should contain "extractKey99"

  Scenario: Duplicate Figma URL returns existing library
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/duptest123/duplicate-test"
    When I send an authenticated POST to "/api/component-libraries" with body:
      """
      { "url": "https://www.figma.com/design/duptest123/duplicate-test" }
      """
    Then the API response status should be 200
    And the API response body should contain the same library id

  Scenario: List user's component libraries
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/component-libraries"
    Then the API response status should be 200
    And the API response body should be a JSON array

  Scenario: View available libraries includes own libraries
    Given the user is logged in as alice
    When I send an authenticated GET to "/api/component-libraries/available"
    Then the API response status should be 200
    And the API response body should be a JSON array

  Scenario: Trigger sync on a library
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/synctest1/sync-trigger"
    When I send an authenticated POST to sync the created library
    Then the API response status should be 200

  Scenario: Library detail includes progress information
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/progresstest1/progress-check"
    When I send an authenticated GET to the created library
    Then the API response status should be 200
    And the API response body should contain field "id"

  Scenario: List components for a library
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/listcomp1/list-components"
    When I send an authenticated GET to the created library components
    Then the API response status should be 200

  Scenario: Re-import a component for nonexistent component returns 404
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/components/999999/reimport"
    Then the API response status should be 404

  Scenario: Re-import a component set for nonexistent returns 404
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/component-sets/999999/reimport"
    Then the API response status should be 404
