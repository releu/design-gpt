@figma-import
Feature: Figma Import
  Users create DESIGN_SYSTEMs by importing FIGMA_FILEs. The system discovers
  components, generates React code, and makes them available for design generation.

  Background:
    Given the user is logged in as "alice@example.com"

  # --- Creating a DESIGN_SYSTEM ---

  @happy-path
  Scenario: Create a new DESIGN_SYSTEM from FIGMA_FILEs
    Given the user is on the home page
    When the user clicks "New design system"
    And adds one or more FIGMA_FILE URLs
    And clicks "import"
    Then a progress bar appears showing the import progress
    When the import finishes
    Then the new DESIGN_SYSTEM opens for the user to review the imported components
    And a success message is shown

  Scenario: Import finishes with errors
    Given the user is creating a new DESIGN_SYSTEM
    And one of the FIGMA_FILEs has components that cannot be converted
    When the import finishes
    Then the DESIGN_SYSTEM opens for review
    And a list of import errors is shown so the user knows what went wrong

  # --- Browsing DESIGN_SYSTEMs ---

  Scenario: Home page shows the user's DESIGN_SYSTEMs
    Given the user owns 3 DESIGN_SYSTEMs
    When the user is on the home page
    Then all 3 DESIGN_SYSTEMs are shown in the list

  Scenario: Home page also shows other users' public DESIGN_SYSTEMs
    Given the user owns 2 DESIGN_SYSTEMs
    And another user has 1 public DESIGN_SYSTEM
    When the user is on the home page
    Then all 3 DESIGN_SYSTEMs are visible
    And each one indicates whether it belongs to the current user

  # --- Syncing ---

  Scenario: Sync all FIGMA_FILEs in a DESIGN_SYSTEM
    Given the user has an existing DESIGN_SYSTEM with 2 FIGMA_FILEs
    When the user triggers a sync for the entire DESIGN_SYSTEM
    Then a progress bar appears showing the sync progress
    And when syncing completes the component browser refreshes with updated components

  Scenario: Sync a single FIGMA_FILE in a DESIGN_SYSTEM
    Given the user has an existing DESIGN_SYSTEM with 2 FIGMA_FILEs
    When the user triggers a sync for one specific file
    Then a progress bar appears for that file's sync
    And only that file's components are re-imported

  Scenario: Sync a single component
    Given the user is viewing a component in a DESIGN_SYSTEM
    When the user triggers a sync for that component
    Then the component is re-imported from Figma
    And the updated component details are shown

  # --- Managing FIGMA_FILEs in a DESIGN_SYSTEM ---

  Scenario: View and manage FIGMA_FILEs in a DESIGN_SYSTEM
    Given the user opens an existing DESIGN_SYSTEM with 2 linked FIGMA_FILEs
    Then each file is listed with its name, an "open" link, and a "remove" link
    When the user clicks "open" on a file
    Then the FIGMA_FILE opens in a new browser tab
    When the user clicks "remove" on a file
    Then the file is removed from this DESIGN_SYSTEM (with confirmation)

  Scenario: Add a FIGMA_FILE to an existing DESIGN_SYSTEM
    Given the user is editing an existing DESIGN_SYSTEM
    When the user adds a new FIGMA_FILE URL to the file list
    And triggers a sync
    Then the new file is imported alongside the existing files
    And the component browser updates with the newly discovered components

  # --- Browsing Components ---

  Scenario: Browse components in a DESIGN_SYSTEM
    Given a DESIGN_SYSTEM has imported components
    When the user opens the DESIGN_SYSTEM
    Then COMPONENT_SETs are listed with their names, VARIANTs, and PROPs
    And standalone COMPONENTs are listed
    And ROOT components are indicated with their SLOTs and ALLOWED_CHILDREN

  # --- Figma Conventions ---

  Scenario: Figma conventions auto-detect ROOT components
    Given a FIGMA_FILE contains a COMPONENT_SET with "#root" in its description
    When the import completes
    Then the COMPONENT_SET is marked as a ROOT component

  Scenario: Figma Slots create SLOTs with ALLOWED_CHILDREN
    Given PAGE has a SLOT named "content" with preferred values [TEXT_COMPONENT, TITLE_COMPONENT]
    When the import completes
    Then the component has a SLOT "content" with ALLOWED_CHILDREN [TEXT_COMPONENT, TITLE_COMPONENT]
    And the SLOT accepts children in the generated code

  Scenario: INSTANCE_SWAP properties also create SLOTs with ALLOWED_CHILDREN
    Given LIB_COMPONENT_WITH_INSTANCE has an INSTANCE_SWAP property with preferred values from EXAMPLE_ICONS
    When the import completes
    Then the preferred values become the SLOT's ALLOWED_CHILDREN
    And the component accepts children in the generated code

  Scenario: Import handles VECTOR components
    Given a FIGMA_FILE contains a component that is purely vector-based
    When the import completes
    Then the component is marked as a VECTOR
    And an SVG image is available for it

  Scenario: Figma conventions auto-detect IMAGE components via description
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component is a plain rectangle frame with a background fill, no children, and no corner radius
    When the import completes
    Then the component is marked as an IMAGE component
    And IMAGE components are excluded from SLOT ALLOWED_CHILDREN lists

  Scenario: IMAGE component with children is imported with a validation warning
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component has child nodes
    When the import completes
    Then the component is marked as an IMAGE component
    And the component has a validation warning about having children

  Scenario: IMAGE component with component properties is imported with a validation warning
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component has VARIANT, BOOLEAN, or TEXT properties
    When the import completes
    Then the component is marked as an IMAGE component
    And the component has a validation warning about having component properties

  Scenario: IMAGE component with corner radius is imported with a validation warning
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component has a non-zero corner radius
    When the import completes
    Then the component is marked as an IMAGE component
    And the component has a validation warning about having corner radius

  Scenario: IMAGE component with multiple issues carries all validation warnings
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component has child nodes AND a non-zero corner radius
    When the import completes
    Then the component is marked as an IMAGE component
    And the component has a validation warning for each issue

  # --- General Validation Warnings ---
  # Any component that fails validation is imported but flagged with warnings.
  # Components with warnings are visible in the browser but excluded from AI generation.

  Scenario: Component with glass effect is imported with a validation warning
    Given a FIGMA_FILE contains a component that uses a glass (frosted glass) effect
    When the import completes
    Then the component has a validation warning about the glass effect

  Scenario: Component with overflowing children is imported with a validation warning
    Given a FIGMA_FILE contains a component with auto-layout
    And a child extends beyond the parent bounds without clipping enabled
    When the import completes
    Then the component has a validation warning about overflowing content

  Scenario: Component with skewed or distorted transform is imported with a validation warning
    Given a FIGMA_FILE contains a component with a non-uniform transform (shear or skew)
    When the import completes
    Then the component has a validation warning about unsupported transforms

  Scenario: Component with scrolling content is imported with a validation warning
    Given a FIGMA_FILE contains a component with scrollable overflow
    When the import completes
    Then the component has a validation warning about scrolling content

  Scenario: Component with fixed-position elements is imported with a validation warning
    Given a FIGMA_FILE contains a component with fixed-position layers
    When the import completes
    Then the component has a validation warning about fixed-position elements

  Scenario: Component with multiple validation issues carries all warnings
    Given a FIGMA_FILE contains a component with a glass effect AND overflowing children
    When the import completes
    Then the component has a validation warning for each issue

  Scenario: Components with validation warnings are imported but flagged
    Given a FIGMA_FILE contains components that fail validation
    When the import completes
    Then those components are imported into the DESIGN_SYSTEM
    And each component has validation warnings describing the issues
    And the import summary indicates how many components have warnings

  # --- Error Handling ---

  Scenario: Import fails on Figma API error
    Given the user is importing a DESIGN_SYSTEM with an invalid FIGMA_FILE URL
    When the import runs
    Then the error is shown to the user with a descriptive message

  Scenario: Individual component errors are visible after import
    Given the user opens a DESIGN_SYSTEM after import
    And some components failed code generation
    Then those components show a "no code" badge
    And the user can trigger a re-import for individual failed components
