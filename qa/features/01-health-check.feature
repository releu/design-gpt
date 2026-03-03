@infrastructure
Feature: Health Check
  The API and frontend must be reachable through the Caddy reverse proxy.

  @critical
  Scenario: API health endpoint responds
    When I send a GET request to "/api/up"
    Then the response status should be 200

  @critical
  Scenario: Frontend loads through Caddy proxy
    Given I navigate to the home page
    Then the app container should be visible
    And the page should contain the Vue app mount point
