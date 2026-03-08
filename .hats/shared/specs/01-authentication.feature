@auth
Feature: Authentication
  Users must sign in before accessing any application functionality.

  Background:
    Given the application is running

  @happy-path
  Scenario: Unauthenticated user sees sign-in screen
    When a user visits the home page without being logged in
    Then a sign-in control is shown
    And no application content is visible behind the sign-in screen

  @happy-path
  Scenario: Clicking the sign-in control initiates login
    Given the user is on the sign-in screen
    When the user clicks the sign-in control
    Then the browser redirects to the hosted login page

  @happy-path
  Scenario: Authenticated user sees the workspace
    Given the user is logged in as "alice@example.com"
    When the user visits the home page
    Then the workspace is visible and the user can start generating designs with AI

  Scenario: Unauthenticated requests are rejected
    When a user tries to access the application without signing in
    Then the application refuses access and shows the sign-in screen

  Scenario: Invalid or expired credentials are rejected
    When a user tries to access the application with invalid credentials
    Then the application refuses access and shows the sign-in screen

  Scenario: Token refresh on expiry
    Given the user is logged in as "alice@example.com"
    And the session has expired
    When the user performs an action that requires authentication
    Then the session is silently refreshed
    And the action succeeds without redirecting to the sign-in screen
