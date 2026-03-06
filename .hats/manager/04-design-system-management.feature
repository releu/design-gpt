@design-system
Feature: Design System Management
  Users create and manage DESIGN_SYSTEMs. A DESIGN_SYSTEM groups one or more
  FIGMA_FILEs and serves as the component palette for AI design generation.
  Configuration (ROOT components, SLOTs, ALLOWED_CHILDREN) is set automatically
  from Figma and is read-only.

  Background:
    Given the user is logged in as "alice@example.com"

  Scenario: Create a new DESIGN_SYSTEM
    Given the user is on the home page
    When the user creates a new DESIGN_SYSTEM
    And enters a name "My Design System"
    And adds a FIGMA_FILE URL
    Then the import begins and progress is visible
    When the import completes
    Then the user can browse the imported components
    And the name is saved automatically
    When the user finishes editing
    Then the DESIGN_SYSTEM appears on the home page

  Scenario: Create a DESIGN_SYSTEM with multiple FIGMA_FILEs
    When the user creates a DESIGN_SYSTEM with 2 FIGMA_FILEs
    Then the DESIGN_SYSTEM is created with both files linked

  Scenario: List user's DESIGN_SYSTEMs
    Given the user has 2 DESIGN_SYSTEMs
    When the user is on the home page
    Then both DESIGN_SYSTEMs are shown

  Scenario: Edit an existing DESIGN_SYSTEM
    Given the user has a DESIGN_SYSTEM "Example" with 2 linked FIGMA_FILEs
    When the user opens "Example" for editing
    Then the name, linked files, and components are shown
    When the user edits the name or the list of FIGMA_FILEs
    And clicks save
    Then the changes are persisted

  Scenario: Browse components grouped by FIGMA_FILE
    Given the user is browsing a DESIGN_SYSTEM with components from 2 FIGMA_FILEs
    Then components are grouped under their FIGMA_FILE names

  Scenario: View component detail
    Given the user is browsing a DESIGN_SYSTEM with imported components
    When the user selects TEXT_COMPONENT
    Then the component detail is shown with name, link to Figma, and sync action

  Scenario: Component detail shows interactive PROPs
    Given the user is viewing TITLE_COMPONENT which has PROPs "size" (VARIANT), "marker" (boolean), and "text" (string)
    Then each PROP has an interactive control matching its type
    And changing a PROP value updates the live PREVIEW

  Scenario: Component detail shows live PREVIEW
    Given the user is viewing TEXT_COMPONENT
    Then a live PREVIEW shows the component with current PROP values
    When the user changes a PROP value
    Then the PREVIEW updates

  Scenario: Component detail shows React code
    Given the user is viewing TEXT_COMPONENT that has generated React code
    Then the user can view the component's React source code

  Scenario: View AI Schema shows component tree reachable from ROOT
    Given the DESIGN_SYSTEM has a ROOT component PAGE with SLOTs
    When the user opens the AI Schema view
    Then a tree is displayed starting from PAGE
    And each SLOT shows its ALLOWED_CHILDREN

  Scenario: DESIGN_SYSTEM with no ROOT components shows empty AI Schema
    Given the DESIGN_SYSTEM has no ROOT components
    When the user views the AI Schema
    Then a message explains that no ROOT components were found and how to mark them in Figma

  Scenario: Component with no React code shows a message
    Given a component failed React code generation
    When the user views the component detail
    Then a message indicates that React code is not available
