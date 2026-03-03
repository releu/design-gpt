@infrastructure
Feature: Health Check
  The API and frontend must be reachable through the Caddy reverse proxy.
  Technical: Caddy on port 443 routes /api/* to Rails (port 3000),
  everything else to Vite (port 5173). TLS is self-signed via "tls internal".

  @critical @happy-path
  Scenario: API health endpoint responds
    When I send a GET request to "/api/up"
    Then the response status should be 200

  @critical @happy-path
  Scenario: Frontend loads through Caddy proxy
    When I navigate to "https://design-gpt.localtest.me"
    Then the HTML page should load successfully
    And the page should contain the Vue app container element
