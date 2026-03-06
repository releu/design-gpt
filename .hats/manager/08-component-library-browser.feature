@component-browser
Feature: Component Browser
  Users can browse imported components and inspect their details:
  link to Figma, sync, PROPs with live PREVIEW updates, ALLOWED_CHILDREN,
  React code, AI Schema, and raw Figma JSON.

  Background:
    Given the user is logged in as "alice@example.com"

  # --- Browsing ---

  Scenario: Components are grouped by FIGMA_FILE
    Given the user is browsing a DESIGN_SYSTEM with components from 2 FIGMA_FILEs
    Then components are grouped under their FIGMA_FILE names

  # --- Component Detail ---

  @happy-path
  Scenario: Component detail shows a link to the Figma source
    Given the user is viewing TITLE_COMPONENT
    Then a link to the component's Figma source is shown

  @happy-path
  Scenario: Sync button re-imports the component from Figma
    Given the user is viewing TITLE_COMPONENT
    When the user clicks the sync button
    Then the component is re-imported from Figma
    And the updated component details are shown

  @happy-path
  Scenario: Component detail lists all PROPs
    Given the user is viewing TITLE_COMPONENT with PROPs "size" (VARIANT), "marker" (boolean), and "text" (string)
    Then all three PROPs are listed with their types

  Scenario: Component detail shows ALLOWED_CHILDREN for components with SLOTs
    Given the user is viewing PAGE_COMPONENT which has a SLOT "content" with ALLOWED_CHILDREN [TITLE_COMPONENT, TEXT_COMPONENT]
    Then the SLOT "content" and its ALLOWED_CHILDREN are shown

  Scenario: VARIANT PROP has a select control that updates the PREVIEW
    Given the user is viewing TITLE_COMPONENT with a VARIANT PROP "size" with values ["m", "l"]
    When the user selects "m" for the "size" PROP
    Then the PREVIEW updates to show the "m" variant

  Scenario: Boolean PROP has a checkbox that updates the PREVIEW
    Given the user is viewing TITLE_COMPONENT with a boolean PROP "marker"
    When the user toggles the "marker" checkbox
    Then the PREVIEW updates to reflect the new value

  Scenario: String PROP has a text input that updates the PREVIEW
    Given the user is viewing TITLE_COMPONENT with a string PROP "text"
    When the user types "Hello World" into the "text" input
    Then the PREVIEW updates to display "Hello World"

  Scenario: Component detail shows React code
    Given the user is viewing TEXT_COMPONENT that has generated React code
    Then the user can view the component's React source code

  Scenario: Component with no React code shows a message
    Given a component failed React code generation
    When the user views the component detail
    Then a message indicates that React code is not available

  # --- AI Schema ---

  Scenario: AI Schema shows component tree reachable from ROOT
    Given the DESIGN_SYSTEM has a ROOT component PAGE with SLOTs
    When the user opens the AI Schema view
    Then a tree is displayed starting from PAGE
    And each SLOT shows its ALLOWED_CHILDREN

  Scenario: DESIGN_SYSTEM with no ROOT components shows empty AI Schema
    Given the DESIGN_SYSTEM has no ROOT components
    When the user views the AI Schema
    Then a message explains that no ROOT components were found and how to mark them in Figma

  # --- Figma JSON ---

  Scenario: Component detail shows raw Figma JSON
    Given the user is viewing TITLE_COMPONENT
    When the user opens the Figma JSON section
    Then the Figma JSON is fetched on demand
    And displayed in a formatted code block

  Scenario: COMPONENT_SET shows Figma JSON for all VARIANTs
    Given the user is viewing a COMPONENT_SET
    When the user opens the Figma JSON section
    Then the Figma JSON for all VARIANTs is shown
