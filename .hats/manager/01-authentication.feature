@auth
Feature: Authentication
  Users must authenticate via Auth0 before accessing any application functionality.
  Technical: Auth0 with RS256 JWT, auto-create User on first login.
  E2E mode uses HS256 HMAC tokens signed with a shared secret.
  UI reference: designer/03-authentication-screen.md

  Background:
    Given the application is running at "https://design-gpt.localtest.me"

  @critical @happy-path
  Scenario: Unauthenticated user sees sign-in screen
    When a user visits the home page without being logged in
    Then the page background should be warm gray (#EBEBEA)
    And a white card (~120x120px, 16px border-radius, subtle shadow) should be centered on screen
    And the card should contain a wave icon (~80px)
    And a "Sign in to continue" label should appear below the card in secondary text color
    And no application content (prompt area, design system selector, preview) should be shown

  @critical @happy-path
  Scenario: Clicking the sign-in card initiates Auth0 login
    Given the user is on the unauthenticated sign-in screen
    When the user clicks the wave icon card
    Then the browser should redirect to the Auth0 hosted login page

  @critical @happy-path
  Scenario: Authenticated user sees the main application
    Given the user is logged in as "alice@example.com"
    When the user visits the home page
    Then the app container should be visible
    And the header bar should be visible with design selector, mode selector, more button, and preview selector
    And the prompt panel should be visible in the left column
    And the design system panel should be visible in the center column
    And the AI engine bar should be visible spanning the left and center columns
    And the preview frame should be visible in the right column

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

  @error-handling
  Scenario: Auth0 login error shows message on sign-in screen
    Given the user is on the unauthenticated sign-in screen
    When Auth0 returns an error after the login attempt
    Then the user should remain on the sign-in screen
    And an error message should be displayed below the wave icon card
