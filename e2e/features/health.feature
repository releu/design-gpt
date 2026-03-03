Feature: Health Check

  Scenario: API health endpoint responds
    When I send a GET request to "/api/up"
    Then the response status should be OK

  Scenario: Frontend loads
    When I navigate to the home page
    Then the app container should be visible
