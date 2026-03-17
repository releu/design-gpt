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

  # --- Public Design Systems ---

  Scenario: Admin marks a DESIGN_SYSTEM as public
    Given an admin has marked "Example" as a public DESIGN_SYSTEM
    Then the DESIGN_SYSTEM is visible to all users on their home page

  Scenario: Home page shows other users' public DESIGN_SYSTEMs
    Given the user owns 2 DESIGN_SYSTEMs
    And another user has 1 public DESIGN_SYSTEM
    When the user is on the home page
    Then all 3 DESIGN_SYSTEMs are visible
    And each one indicates whether it belongs to the current user

  Scenario: Non-owner can view and sync a public DESIGN_SYSTEM
    Given another user has a public DESIGN_SYSTEM "Shared Library"
    When the user opens "Shared Library"
    Then the components are browsable
    And the user can trigger a sync
    But the user cannot edit the name, files, or settings

  # --- Versioning ---

  Scenario: Previous ITERATIONs still render correctly after a sync
    Given a DESIGN was generated before the last sync
    And the DESIGN_SYSTEM has been synced since then
    When the user views the DESIGN's PREVIEW
    Then the PREVIEW renders using the components as they were when the DESIGN was generated

  # --- Sync Queue ---

  Scenario: Sync is queued when another sync is already running
    Given a DESIGN_SYSTEM is currently syncing
    When the user triggers another sync
    Then the sync is added to the queue
    And the user sees their position in the sync queue

  Scenario: Queued sync starts automatically after the previous one finishes
    Given the user's sync is queued behind another sync
    When the previous sync completes
    Then the user's sync starts automatically
    And the progress updates in real time
