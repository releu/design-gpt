@infrastructure
Feature: Health Check
  The API and frontend must be reachable through the reverse proxy.

  Scenario: API health endpoint responds
    When the API health endpoint is checked
    Then the API should report that it is running

  Scenario: Frontend loads through the proxy
    When a user navigates to the application URL
    Then the frontend page loads successfully
    And the application container is present
