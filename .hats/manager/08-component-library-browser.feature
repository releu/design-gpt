@component-browser
Feature: Component Browser
  Users can browse imported components, view them with live PREVIEW,
  inspect React code, and see visual diff results. The component detail
  view is shared across the DESIGN_SYSTEM editor, the settings panel
  on the design page, and the standalone FIGMA_FILE detail page.

  Background:
    Given the user is logged in as "alice@example.com"

  Scenario: View imported FIGMA_FILEs
    Given the user has imported 2 FIGMA_FILEs: EXAMPLE_LIB and EXAMPLE_ICONS
    When the user navigates to the FIGMA_FILEs page
    Then both are shown with their name and component count

  Scenario: Navigate to a FIGMA_FILE's detail page
    Given EXAMPLE_LIB has been imported
    When the user clicks on EXAMPLE_LIB
    Then the detail page opens showing all components

  Scenario: Detail page shows import progress for files still importing
    Given a FIGMA_FILE import has not finished yet
    When the user views its detail page
    Then the import progress is shown

  Scenario: PREVIEW page renders all components
    Given a FIGMA_FILE has COMPONENT_SETs and standalone COMPONENTs
    When the user opens the PREVIEW page
    Then all components are rendered with their names and PREVIEWs
    And VECTOR components display their SVG images

  # --- Component Detail ---

  Scenario: Component detail shows name, Figma link, and sync
    Given the user is viewing TEXT
    Then the component name, link to Figma, and sync action are shown

  Scenario: Component detail shows interactive PROPs
    Given the user is viewing TITLE which has PROPs "size" (VARIANT), "marker" (boolean), and "text" (string)
    Then each PROP has a control matching its type
    And changing a PROP updates the live PREVIEW

  Scenario: Component detail shows live PREVIEW
    Given the user is viewing TEXT
    Then a live PREVIEW shows the component rendered with current PROP values

  Scenario: Component detail shows React code
    Given a component has generated React code
    When the user expands the React code section
    Then the source code is shown in a read-only viewer

  Scenario: Component detail shows configuration (ROOT and SLOTs)
    Given PAGE is marked as ROOT with SLOTs that have ALLOWED_CHILDREN
    When the user views the configuration section
    Then ROOT designation and SLOTs with ALLOWED_CHILDREN are shown

  Scenario: Component detail shows visual diff
    Given a component has Figma and React screenshots
    When the user views the visual diff
    Then the Figma version, React version, and diff are shown with a match percentage

  Scenario: Update FIGMA_FILE visibility
    Given a FIGMA_FILE exists as private
    When the user makes it public
    Then it becomes accessible to other users

  Scenario: Standalone COMPONENT displays correctly
    Given standalone COMPONENT TEXT exists
    When the user views the component detail
    Then the PREVIEW renders the component with default PROPs

  Scenario: Component without React code shows graceful message
    Given a component has no generated React code
    When the user views it
    Then a message indicates the code is not available
