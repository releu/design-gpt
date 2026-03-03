@auth
Feature: Authentication
  Users must authenticate via Auth0 before accessing any application functionality.
  Technical: Auth0 with RS256 JWT, auto-create User on first login.
  E2E mode uses HS256 HMAC tokens signed with a shared secret.

  Background:
    Given the application is running at "https://design-gpt.localtest.me"

  @critical @happy-path
  Scenario: Unauthenticated user sees sign-in prompt
    When a user visits the home page without being logged in
    Then the sign-in prompt should be visible
    And no application content should be shown

  @critical @happy-path
  Scenario: Authenticated user sees the main application
    Given the user is logged in as "alice@example.com"
    When the user visits the home page
    Then the app container should be visible
    And the prompt area should be visible
    And the design system selector should be visible

  @critical @happy-path
  Scenario: Auto-create user on first login
    Given a new user logs in with Auth0 ID "auth0|newuser456" and email "newuser@example.com"
    When the user makes an authenticated API request to GET /api/designs
    Then the response status should be 200
    And a User record with auth0_id "auth0|newuser456" should exist in the database

  @error-handling
  Scenario: API rejects requests without valid token
    When a request is sent to GET /api/designs without an Authorization header
    Then the response status should be 401

  @error-handling
  Scenario: API rejects requests with an expired or invalid token
    When a request is sent to GET /api/designs with an invalid JWT token
    Then the response status should be 401

  @edge-case
  Scenario: Token refresh on expiry
    Given the user is logged in as "alice@example.com"
    And the access token has expired
    When the user performs an action that requires authentication
    Then Auth0 should silently refresh the access token
    And the action should succeed without redirecting to login
