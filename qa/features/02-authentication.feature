@auth
Feature: Authentication
  Users must authenticate via Auth0 before accessing any application functionality.
  E2E mode uses HS256 HMAC tokens signed with a shared secret.

  @critical
  Scenario: Unauthenticated user sees sign-in prompt
    When I navigate to the home page without auth
    Then the sign-in prompt should be visible
    And no application content should be shown

  @critical
  Scenario: Authenticated user sees the main application
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And the prompt area should be visible
    And the design system selector should be visible

  @critical
  Scenario: Auto-create user on first login via API
    Given a new user token for "auth0|newuser456" with email "newuser@example.com"
    When I send an authenticated GET to "/api/designs"
    Then the API response status should be 200

  Scenario: API rejects requests without valid token
    When I send an unauthenticated GET to "/api/designs"
    Then the API response status should be 401

  Scenario: API rejects requests with an invalid JWT token
    When I send a GET to "/api/designs" with an invalid token
    Then the API response status should be 401

  Scenario: Token with expired timestamp is rejected by API
    When I send a GET to "/api/designs" with an expired token
    Then the API response status should be 401
