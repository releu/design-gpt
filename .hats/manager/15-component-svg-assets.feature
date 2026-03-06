@assets
Feature: Component SVG Assets
  VECTOR components from Figma are available as SVG images
  for use in component PREVIEWs.

  Background:
    Given a DESIGN_SYSTEM exists with VECTOR components

  Scenario: View SVG for a VECTOR COMPONENT
    Given a COMPONENT has an SVG image available
    When the user views the COMPONENT
    Then the SVG image is displayed

  Scenario: View SVG for a COMPONENT_SET
    Given a COMPONENT_SET has an SVG image available
    When the user views the COMPONENT_SET
    Then the SVG image is displayed

  Scenario: SVG not available for a COMPONENT
    Given a COMPONENT has no SVG image available
    When the user views the COMPONENT
    Then a placeholder is shown

  Scenario: COMPONENT HTML PREVIEW
    Given a COMPONENT has generated code
    When the user views the COMPONENT's HTML PREVIEW
    Then a standalone page renders the COMPONENT

  Scenario: HTML PREVIEW not available
    Given a COMPONENT has no generated code
    When the user tries to view the HTML PREVIEW
    Then the PREVIEW is not available
