@visual-diff
Feature: Visual Diff
  After import, every COMPONENT and VARIANT is compared against its Figma screenshot.
  Components with low fidelity are highlighted so users can spot problems at a glance.

  Background:
    Given the user is logged in as "alice@example.com"
    And a DESIGN_SYSTEM has been imported

  Scenario: Standalone COMPONENT shows its diff percentage
    Given TEXT_COMPONENT has a visual diff of 97%
    When the user views TEXT_COMPONENT
    Then the diff percentage "97%" is shown

  Scenario: Each VARIANT in a COMPONENT_SET shows its own diff percentage
    Given TITLE_COMPONENT is a COMPONENT_SET with VARIANTs "m" (91%) and "l" (99%)
    When the user views TITLE_COMPONENT
    Then each VARIANT shows its own diff percentage

  Scenario: COMPONENT_SET shows the average diff across all VARIANTs
    Given TITLE_COMPONENT is a COMPONENT_SET with VARIANTs "m" (91%) and "l" (99%)
    When the user views TITLE_COMPONENT
    Then the COMPONENT_SET shows an average diff of 95%

  Scenario: Components below 95% are highlighted
    Given TEXT_COMPONENT has a visual diff of 92%
    When the user browses components
    Then TEXT_COMPONENT is marked as low fidelity

  Scenario: Components at or above 95% are not highlighted
    Given TITLE_COMPONENT has a visual diff of 97%
    When the user browses components
    Then TITLE_COMPONENT has no low fidelity mark
