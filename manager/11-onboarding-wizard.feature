@onboarding
Feature: Onboarding Wizard
  New users can go through a step-by-step wizard to set up their first project.
  The wizard has 4 steps: Prompt, Libraries, Components, and Organize.
  Technical: Route /onboarding, view OnboardingView.vue. Steps use dedicated
  sub-components (OnboardingStepPrompt, OnboardingStepLibraries,
  OnboardingStepComponents, OnboardingStepOrganize). WizardStepper tracks progress.

  Background:
    Given the user is logged in as "alice@example.com"

  @happy-path
  Scenario: Navigate through the onboarding wizard
    When the user visits /onboarding
    Then the wizard should display "New Project Setup" header
    And the stepper should show 4 steps: "Prompt", "Libraries", "Components", "Organize"
    And the first step "Prompt" should be active

  @happy-path
  Scenario: Step 1 - Enter a prompt
    Given the user is on the onboarding Prompt step
    When the user types "Create a travel booking app"
    Then the "Next" button should become enabled
    When the user clicks "Next"
    Then the wizard should advance to the "Libraries" step

  @happy-path
  Scenario: Step 2 - Select and import libraries
    Given the user is on the Libraries step
    And there are 2 available component libraries
    When the user selects 1 library by clicking on it
    Then the library should be highlighted as selected
    And the "Next" button should become enabled
    When the user imports a new Figma file via the URL input
    Then the import progress should be shown
    And when import completes, the new library should appear in the list

  @happy-path
  Scenario: Step 3 - Review imported components
    Given the user is on the Components step
    And the selected libraries contain 5 component sets and 3 standalone components
    Then all components should be listed with their names and types

  @happy-path
  Scenario: Step 4 - Organize components (root and children)
    Given the user is on the Organize step
    When the user toggles "Page" as a root component
    Then a PATCH request should be sent to update is_root
    When the user adds "Card" as an allowed child of "Page"
    Then a PATCH request should update allowed_children to include "Card"

  @happy-path
  Scenario: Complete onboarding creates a project
    Given the user has completed all 4 steps
    When the user clicks "Create Project"
    Then a project should be created with the prompt as description
    And selected libraries should be linked to the project
    And the user should be redirected to the home page

  @edge-case
  Scenario: Cannot proceed from Prompt step with empty prompt
    Given the user is on the Prompt step with no text entered
    Then the "Next" button should appear disabled
    When the user clicks "Next"
    Then the wizard should remain on the Prompt step

  @edge-case
  Scenario: Cannot proceed from Libraries step with no selection
    Given the user is on the Libraries step with no libraries selected
    Then the "Next" button should appear disabled

  @happy-path
  Scenario: Navigate back to previous steps
    Given the user is on the Components step (step 3)
    When the user clicks "Back"
    Then the wizard should return to the Libraries step
    And the previously selected libraries should still be selected
