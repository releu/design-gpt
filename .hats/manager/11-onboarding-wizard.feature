@onboarding
Feature: Onboarding Wizard
  New users go through a step-by-step wizard to set up their first project.
  The wizard has 4 steps: PROMPT, FIGMA_FILEs, Components, Create Project.

  Background:
    Given the user is logged in as "alice@example.com"

  Scenario: Onboarding page shows a stepper with 4 steps
    When the user visits the onboarding page
    Then the stepper shows 4 steps: "Prompt", "Figma Files", "Components", "Create Project"
    And the first step is active

  Scenario: Step 1 - Enter a PROMPT
    Given the user is on the PROMPT step
    When the user types "Create a travel booking app"
    Then the "Next" button becomes enabled
    When the user clicks "Next"
    Then the wizard advances to the FIGMA_FILEs step

  Scenario: Step 2 - Select FIGMA_FILEs
    Given the user is on the FIGMA_FILEs step
    And there are available FIGMA_FILEs
    When the user selects a FIGMA_FILE
    Then the "Next" button becomes enabled

  Scenario: Step 2 - Import a new FIGMA_FILE
    Given the user is on the FIGMA_FILEs step
    When the user enters a Figma URL and starts the import
    Then the import runs and the new FIGMA_FILE appears in the list

  Scenario: Step 3 - Review imported components
    Given the user is on the Components step
    Then the imported COMPONENT_SETs and standalone COMPONENTs are listed
    And the "Next" button is enabled (this step is informational)

  Scenario: Step 4 - Create project
    Given the user is on the final step
    When the user clicks "Create Project"
    Then a DESIGN_SYSTEM is created with the selected FIGMA_FILEs
    And an initial DESIGN is created with the PROMPT
    And the user is redirected to the home page

  Scenario: Cannot proceed from PROMPT step with empty PROMPT
    Given the user is on the PROMPT step with no text entered
    Then the "Next" button is disabled

  Scenario: Cannot proceed from FIGMA_FILEs step with no selection
    Given the user is on the FIGMA_FILEs step with no FIGMA_FILEs selected
    Then the "Next" button is disabled

  Scenario: Navigate back preserves entered data
    Given the user is on Step 3
    When the user navigates back to Step 1
    Then the previously entered PROMPT and FIGMA_FILE selections are preserved
