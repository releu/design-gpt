@design-management
Feature: Design Management
  Users can list, view, and export their DESIGNs.
  Each DESIGN is identified by a number (e.g. DESIGN #132).

  Background:
    Given the user is logged in as "alice@example.com"

  Scenario: List all user DESIGNs
    Given the user has 5 DESIGNs
    When the user views their DESIGN list
    Then all 5 DESIGNs are shown ordered by most recent first

  Scenario: View a specific DESIGN
    Given DESIGN #132 exists
    When the user opens DESIGN #132
    Then the design page shows the PREVIEW and chat history

  Scenario: Switch between DESIGNs via the design selector
    Given the user has DESIGN #132 and DESIGN #133
    When the user clicks the design selector
    Then they can switch to any DESIGN or create a new one

  Scenario: Export DESIGN as PNG image
    Given DESIGN #132 has a generated PREVIEW
    When the user exports the DESIGN as an image
    Then a PNG file is downloaded

  Scenario: Export DESIGN as React project
    Given DESIGN #132 has a generated PREVIEW
    When the user exports the DESIGN as a React project
    Then a zip file is downloaded

  Scenario: Export menu
    Given the user is on the design page for DESIGN #132
    When the user opens the export menu
    Then options for downloading React project, image, and exporting to Figma are available

  Scenario: Export to Figma
    Given the user is on the design page for DESIGN #132
    When the user chooses "Export to Figma"
    Then an instruction is shown to open the DesignGPT Figma plugin
    And a code is provided that the user can copy and paste into the plugin

  Scenario: Export unavailable when DESIGN has no PREVIEW
    Given a DESIGN has no generated PREVIEW
    Then export options are not available

  Scenario: Cannot access another user's DESIGN
    Given a DESIGN belongs to a different user
    When the current user tries to view the DESIGN
    Then the DESIGN is not found

  # --- Shared Design Links ---

  Scenario: Share a DESIGN via link
    Given DESIGN #132 has a generated PREVIEW
    When the user copies the share link
    Then a URL containing the ITERATION's share code is provided

  Scenario: View a shared DESIGN without authentication
    Given an ITERATION has share code "abc123"
    When an unauthenticated user visits /share/abc123
    Then the DESIGN name, JSX, and share code are returned
    And no login is required

  Scenario: Export from shared link without authentication
    Given an ITERATION has share code "abc123"
    When an unauthenticated user requests /iterations/abc123/export-react
    Then a zip file is downloaded
    When an unauthenticated user requests /iterations/abc123/export-figma
    Then the Figma export JSON is returned
