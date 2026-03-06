@design-generation
Feature: Design Generation
  Users enter a text PROMPT and select a DESIGN_SYSTEM. The AI generates
  a DESIGN using the system's components, and a live PREVIEW renders it.

  Background:
    Given the user is logged in as "alice@example.com"
    And a DESIGN_SYSTEM "Example" exists with ROOT component PAGE and ALLOWED_CHILDREN [TITLE, TEXT]

  # --- Home Page ---

  Scenario: Home page has PROMPT, DESIGN_SYSTEM, and PREVIEW areas
    Given the user is on the home page
    Then the user can enter a design description
    And the user can select a DESIGN_SYSTEM
    And the PREVIEW area is visible
    And a "generate" button is available

  Scenario: DESIGN_SYSTEM panel shows available DESIGN_SYSTEMs
    Given the user has DESIGN_SYSTEMs "common/depot", "releu/depot", "andreas/cubes"
    And the user is on the home page
    Then the available DESIGN_SYSTEMs are listed
    And the user can select one and edit it
    And a "new" button is available to create a new DESIGN_SYSTEM

  @happy-path
  Scenario: Generate a DESIGN from a PROMPT
    Given the user is on the home page
    When the user enters the PROMPT "List top 5 parks in Amsterdam"
    And selects the DESIGN_SYSTEM "Example"
    And clicks "generate"
    Then the user is taken to the design page
    And the design page shows the chat and PREVIEW

  @happy-path
  Scenario: Design generation completes and PREVIEW renders
    Given a DESIGN is being generated
    When the AI generation completes
    Then the PREVIEW shows the generated DESIGN

  # --- Design Page ---

  Scenario: PREVIEW selector switches between phone, desktop, and code views
    Given the user is on a design page with a generated PREVIEW
    Then the user can switch between "phone", "desktop", and "code" PREVIEW modes
    And each mode shows the PREVIEW in a different layout

  Scenario: DESIGN selector dropdown
    Given the user has 3 DESIGNs
    When the user is on a design page
    Then the user can switch between DESIGNs via the design selector
    And "(+) new design" takes the user back to the home page

  # --- Generating State ---

  Scenario: Design page during generation
    Given the DESIGN is being generated
    Then the PREVIEW shows a loading state
    And the chat input is disabled
    When the generation completes
    Then the PREVIEW shows the generated DESIGN
    And the chat input becomes enabled

  # --- Code View ---

  Scenario: Code view shows editable JSX
    Given the user is on a design page with a generated PREVIEW
    When the user switches to "code" view
    Then the code editor shows the generated JSX
    And the code is editable

  Scenario: Editing JSX updates the PREVIEW
    Given the user is viewing the code editor
    When the user edits the JSX code
    Then the PREVIEW re-renders with the updated JSX
    And the changes are saved automatically

  Scenario: Reset JSX to a previous ITERATION
    Given a DESIGN has multiple ITERATIONs
    When the user clicks the reset button on a previous ITERATION's chat message
    Then the code and PREVIEW revert to that ITERATION

  # --- Edge Cases ---

  Scenario: New user with no DESIGN_SYSTEMs sees generate button disabled
    Given the user has no DESIGN_SYSTEMs
    And the user is on the home page
    Then the "generate" button is disabled

  Scenario: Generate without selecting a DESIGN_SYSTEM fails
    When the user tries to generate a DESIGN without selecting a DESIGN_SYSTEM
    Then the generation fails

  Scenario: AI generation fails and DESIGN shows error message
    Given a DESIGN is being generated
    When the AI generation fails
    Then the DESIGN shows an error message
    And the user can retry by sending a new message in the chat
