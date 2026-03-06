@component-browser
Feature: Component Browser
  Users can browse imported components and inspect their details:
  link to Figma, sync, PROPs with live PREVIEW updates, and ALLOWED_CHILDREN.

  Background:
    Given the user is logged in as "alice@example.com"

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
