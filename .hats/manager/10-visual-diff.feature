@visual-diff
Feature: Visual Diff Comparison
  After component import and React code generation, the system compares
  Figma screenshots with React-rendered screenshots to measure fidelity.

  Background:
    Given the user is logged in as "alice@example.com"
    And a DESIGN_SYSTEM exists with imported components

  Scenario: Visual diff results are available for a COMPONENT
    Given TEXT has completed visual diff with 92% match
    When the user views the visual diff for TEXT
    Then the match percentage shows 92%
    And a diff image is available
    And both Figma and React screenshots are available

  Scenario: View diff image for a COMPONENT
    Given a COMPONENT has a diff image generated
    When the user views the diff image
    Then a comparison image is shown

  Scenario: View Figma screenshot for a COMPONENT
    Given a COMPONENT has a Figma screenshot
    When the user views the Figma screenshot
    Then the original Figma rendering is shown

  Scenario: View React screenshot for a COMPONENT
    Given a COMPONENT has a React screenshot
    When the user views the React screenshot
    Then the React-rendered version is shown

  Scenario: Match percentage displayed in component detail
    Given ICON_SET has a default VARIANT with 87% match
    When the user views the component detail for ICON_SET
    Then a match badge displays "87% match"

  Scenario: COMPONENT without visual diff shows no match data
    Given a COMPONENT exists that has not been diffed yet
    When the user views the visual diff
    Then no match percentage is shown
    And no screenshots are available

  Scenario: Diff image not available
    Given a COMPONENT has no diff image
    When the user tries to view the diff image
    Then the image is not available

  Scenario: Invalid screenshot type is rejected
    When the user requests an invalid screenshot type
    Then the request is rejected with an error
