@mode:serial
@timeout:600000
Feature: Onboarding Wizard
  New users can go through a step-by-step wizard to set up their first project.
  The wizard has 4 steps: Prompt, Libraries, Components, and Organize.
  Route /onboarding, view OnboardingView.vue.
  UI reference: designer/08-onboarding-wizard.md

  # --- Page Layout ---

  Scenario: Onboarding page has warm gray background with centered container
    Given I navigate to the onboarding page
    Then the onboarding page background should be warm gray
    And a centered container should be visible with max-width around 900px
    And the title "New Project Setup" should be at the top

  # --- Stepper ---

  Scenario: Stepper displays 4 steps with visual state indicators
    Given I navigate to the onboarding page
    Then the stepper should show 4 steps
    And each step should be a numbered circle with label connected by lines
    And the first step "Prompt" should be active
    And upcoming steps should show outline circles

  Scenario: Step content area is a white card with rounded corners
    Given I navigate to the onboarding page
    Then the step content should be in a white card below the stepper

  # --- Navigation Buttons ---

  Scenario: Navigation buttons have correct styling
    Given I navigate to the onboarding page
    Then the "Next" button should be pill-shaped with dark background
    And on step 1 the "Back" button should be hidden

  # --- Step 1: Prompt ---

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

  # --- Step 2: Libraries ---

  Scenario: Step 2 - Select and import libraries
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

  # --- Step 3: Components ---

  Scenario: Step 3 - Review imported components grouped by type
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Components" step
    And the components list should display imported components

  # --- Step 4: Organize ---

  Scenario: Step 4 - Organize components with root and children
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Organize" step

  Scenario: Step 4 shows "Create Project" instead of "Next"
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    And I select the first available library
    And I click the "Next" button in the wizard
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Organize" step
    And the final button should show "Create Project" label

  # --- Navigation ---

  Scenario: Navigate back preserves entered data
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step
    When I click the "Back" button in the wizard
    Then the wizard should remain on step 1
    And the onboarding prompt should still contain "Test project"

  Scenario: Stepper updates as user progresses
    Given I navigate to the onboarding page
    And I type a prompt "Test project" in the onboarding prompt
    And I click the "Next" button in the wizard
    Then the wizard should advance to the "Libraries" step
    And the stepper should show step 1 as completed
    And step 2 should be active

  # --- Completion ---

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
