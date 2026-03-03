@onboarding
Feature: Onboarding Wizard
  New users can go through a step-by-step wizard to set up their first project.
  The wizard has 4 steps: Prompt, Libraries, Components, and Organize.
  Technical: Route /onboarding, view OnboardingView.vue. Steps use dedicated
  sub-components (OnboardingStepPrompt, OnboardingStepLibraries,
  OnboardingStepComponents, OnboardingStepOrganize). WizardStepper tracks progress.
  UI reference: designer/08-onboarding-wizard.md

  Background:
    Given the user is logged in as "alice@example.com"

  # --- Page Layout ---

  @happy-path
  Scenario: Onboarding page layout
    When the user visits /onboarding
    Then the page background should be warm gray (--bg-page)
    And a centered container should appear (max-width ~900px, 32px padding)
    And the title "New Project Setup" should be at the top (20px, bold, left-aligned)

  @happy-path
  Scenario: Stepper displays 4 steps with visual state indicators
    When the user visits /onboarding
    Then the stepper should show 4 steps: "Prompt", "Libraries", "Components", "Organize"
    And each step should be a numbered circle + label connected by horizontal lines
    And the first step "Prompt" should be active (filled circle with ring emphasis, bold label)
    And upcoming steps should show empty circle outlines with secondary text labels
    And connecting lines between completed steps should be solid
    And connecting lines to upcoming steps should be dashed or lighter

  @happy-path
  Scenario: Step content area is a white card
    When the user visits /onboarding
    Then the step content area should be a white card below the stepper
    And the card should have 24px border-radius (--radius-lg) and 24px padding (--sp-4)

  @happy-path
  Scenario: Navigation buttons below the step content
    When the user is on any onboarding step
    Then the "Next" button should appear below the step content (right-aligned)
    And the "Next" button should be pill-shaped with near-black background and white text
    And on Step 1 the "Back" button should be hidden (no previous step)
    And on Steps 2-4 a "Back" button should appear (ghost/outline style, transparent background, primary text)

  # --- Step 1: Prompt ---

  @happy-path
  Scenario: Step 1 - Enter a prompt
    Given the user is on the onboarding Prompt step
    Then instruction text "Describe what you want to create" should be visible (14px, primary text)
    And a large multi-line textarea should be present (same style as home page prompt panel)
    And the textarea placeholder should be in secondary text color
    When the user types "Create a travel booking app"
    Then the "Next" button should become enabled
    When the user clicks "Next"
    Then the wizard should advance to the "Libraries" step
    And the "Prompt" step in the stepper should show as completed (filled circle)

  # --- Step 2: Libraries ---

  @happy-path
  Scenario: Step 2 - Select and import libraries
    Given the user is on the Libraries step
    And there are 2 available component libraries
    Then instruction text "Select component libraries for your project" should be visible
    And a card-based list of libraries should be shown
    And each library row should display:
      | element                | description                                      |
      | checkbox/selection     | Filled when selected, empty when not              |
      | library name           | Primary text, 14px                                |
      | status badge           | Pill-shaped: "ready", "importing", etc.           |
      | component count        | Secondary text, 13px                              |
    When the user clicks on a library row
    Then the row should become highlighted with light gray background (--bg-chip-active)
    And the checkbox should become filled
    And the "Next" button should become enabled

  @happy-path
  Scenario: Step 2 - Import a new library from Figma
    Given the user is on the Libraries step
    Then below the library list there should be an "Import from Figma:" label
    And a Figma URL text input with an "Import" button (pill-shaped, --accent-primary)
    When the user enters a Figma URL and clicks "Import"
    Then a progress indicator should replace the "Import" button while importing
    And when import completes, the new library should appear in the list above

  # --- Step 3: Components ---

  @happy-path
  Scenario: Step 3 - Review imported components grouped by type
    Given the user is on the Components step
    And the selected libraries contain 5 component sets and 3 standalone components
    Then instruction text "Review imported components" should be visible
    And a "Component Sets (5)" section header should be shown (14px, bold)
    And each component set row should show: name (14px), "Component Set" type badge (pill, secondary), variant count
    And a "Standalone Components (3)" section header should be shown below
    And each standalone row should show: name, "Component" type badge, optional extra info (e.g. "(vector)")
    And the "Next" button should always be enabled on this step (informational only)

  # --- Step 4: Organize ---

  @happy-path
  Scenario: Step 4 - Organize components with root and children
    Given the user is on the Organize step
    Then instruction text "Organize your components" should be visible
    And a description explaining root components and nesting should appear
    And each component set should be listed as a row with:
      | element            | description                                          |
      | name               | Component name, 14px                                 |
      | root checkbox      | Labeled "Root", checked if is_root=true              |
      | children tags      | Pill-shaped tags showing allowed child component names |
      | add children [+]   | Button to add more children (opens dropdown)         |
      | remove tag (x)     | Each child tag is removable                          |
    And a note in secondary text should explain Figma conventions (#root suffix, INSTANCE_SWAP)
    When the user toggles "Page" as a root component
    Then a PATCH request should be sent to update is_root
    When the user adds "Card" as an allowed child of "Page" via the [+] button
    Then a PATCH request should update allowed_children to include "Card"
    When the user clicks (x) on a child tag to remove it
    Then a PATCH request should update allowed_children to exclude that child

  @happy-path
  Scenario: Step 4 shows "Create Project" instead of "Next"
    Given the user is on the Organize step (step 4)
    Then the "Next" button should show "Create Project" label instead
    And the button should use the same dark pill styling

  # --- Completion ---

  @happy-path
  Scenario: Complete onboarding creates a project
    Given the user has completed all 4 steps
    When the user clicks "Create Project"
    Then a design system should be created with the selected libraries
    And an initial design should be created with the prompt as description
    And the user should be redirected to the home page with the new design system available

  # --- Edge Cases ---

  @edge-case
  Scenario: Cannot proceed from Prompt step with empty prompt
    Given the user is on the Prompt step with no text entered
    Then the "Next" button should appear disabled (gray, no pointer cursor)
    When the user clicks "Next"
    Then the wizard should remain on the Prompt step

  @edge-case
  Scenario: Cannot proceed from Libraries step with no selection
    Given the user is on the Libraries step with no libraries selected
    Then the "Next" button should appear disabled (gray, no pointer cursor)

  # --- Navigation ---

  @happy-path
  Scenario: Navigate back preserves entered data
    Given the user is on the Components step (step 3)
    When the user clicks "Back"
    Then the wizard should return to the Libraries step
    And the previously selected libraries should still be selected
    When the user clicks "Back" again
    Then the wizard should return to the Prompt step
    And the previously entered prompt text should still be present

  @happy-path
  Scenario: Stepper updates as user progresses
    Given the user has completed Step 1 and is on Step 2
    Then the stepper should show Step 1 as completed (filled circle, solid connecting line)
    And Step 2 should show as active (filled circle with emphasis, bold label)
    And Steps 3-4 should show as upcoming (outline circles, dashed connecting lines)
