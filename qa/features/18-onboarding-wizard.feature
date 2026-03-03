@mode:serial
@timeout:600000
Feature: Onboarding Wizard
  New users can go through a step-by-step wizard to set up their first project.
  The wizard has 4 steps: Prompt, Libraries, Components, and Organize.
  Route /onboarding, view OnboardingView.vue.

  Scenario: Navigate through the onboarding wizard
    Given I navigate to the onboarding page
    Then the wizard should display the "New Project Setup" header
    And the stepper should show 4 steps
    And the first step "Prompt" should be active

  Scenario: Step 1 - Enter a prompt and proceed
    Given I navigate to the onboarding page
    And the first step "Prompt" should be active
    Then the "Next" button should appear disabled
    When I type a prompt "Create a travel booking app" in the onboarding prompt
    Then the "Next" button should become enabled
    When I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step

  Scenario: Cannot proceed from Prompt step with empty prompt
    Given I navigate to the onboarding page
    And the first step "Prompt" should be active
    Then the "Next" button should appear disabled
    When I click the "Next" button in the wizard
    Then the wizard should remain on step 1

  Scenario: Step 2 - Select a library
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step
    And the "Next" button should appear disabled
    When I select the first available library
    Then the selected library should be highlighted
    And the "Next" button should become enabled

  Scenario: Cannot proceed from Libraries step with no selection
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step
    And the "Next" button should appear disabled

  Scenario: Step 3 - Review imported components
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Components" step
    And the components list should display imported components

  Scenario: Step 4 - Organize components
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Organize" step

  Scenario: Navigate back to previous steps
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step
    When I click the "Back" button in the wizard
    Then the wizard should remain on step 1
    And the onboarding prompt should still contain "Test project"

  Scenario: Complete onboarding creates a project
    Given I navigate to the onboarding page
    And I type a prompt "Test project for completion" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    And I click the "Next" button in the wizard
    And I click the "Next" button in the wizard
    When I click the "Create Project" button in the wizard
    Then I should be navigated to the home page
