@figma-export
Feature: Figma Plugin Export
  Users export a DESIGN to Figma. The service provides a share code, the user
  pastes it into the DesignGPT Figma plugin, and the plugin recreates the design
  using real library components in Figma.

  # --- Export Flow ---

  @happy-path
  Scenario: Export a DESIGN to Figma via share code
    Given the user is on the design page
    When the user opens the export menu and chooses "Export to Figma"
    Then a share code is displayed with copy-to-clipboard
    And instructions are shown to paste the code into the DesignGPT Figma plugin

  Scenario: Plugin renders the design in Figma
    Given the user has pasted the share code into the Figma plugin
    When the plugin processes the design
    Then the design is recreated using real library component instances
    And PROPs, SLOTs, and IMAGE fills are applied

  # --- Error Handling ---

  Scenario: Plugin reports component schema mismatch
    Given the DESIGN_SYSTEM components have changed since the design was generated
    When the plugin tries to render the design
    Then the plugin shows an error that the component schema has changed

  Scenario: Plugin reports invalid share code
    Given the user pastes an invalid or expired share code
    When the plugin tries to fetch the design
    Then the plugin shows an error that the code is not valid
