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
