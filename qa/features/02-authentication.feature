@auth
Feature: Authentication
  Users must authenticate via Auth0 before accessing any application functionality.
  E2E mode uses HS256 HMAC tokens signed with a shared secret.
  UI reference: designer/03-authentication-screen.md

  # --- Sign-in Screen UI ---

  @critical
  Scenario: Unauthenticated user sees sign-in screen with wave icon card
    When I navigate to the home page without auth
    Then the page background should be warm gray
    And a centered white card should be visible with rounded corners and shadow
    And the card should contain a wave icon
    And a "Sign in to continue" label should appear below the card
    And no application content should be shown

  @critical
  Scenario: Clicking the sign-in card initiates Auth0 login
    When I navigate to the home page without auth
    Then the sign-in card should be clickable
    When I click the sign-in card
    Then the browser should begin the Auth0 login redirect

  # --- Authenticated User ---

  @critical
  Scenario: Authenticated user sees the main application with all panels
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And the header bar should be visible
    And the header bar should contain the design selector
    And the header bar should contain the mode selector
    And the header bar should contain the more button
    And the header bar should contain the preview selector
    And the prompt panel should be visible
    And the design system panel should be visible
    And the preview frame should be visible in the right column

  # --- API Authentication ---

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

  # --- Error Handling ---

  Scenario: Auth0 login error keeps user on sign-in screen
    When I navigate to the home page without auth
    Then the sign-in card should be visible
    And if Auth0 returns an error the user should remain on the sign-in screen
