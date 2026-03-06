@preview-rendering
Feature: Preview Rendering
  The PREVIEW renders generated JSX using components from the DESIGN_SYSTEM.
  It updates automatically when the code changes.

  Background:
    Given a DESIGN_SYSTEM exists with imported components

  Scenario: PREVIEW loads with all components available
    When the PREVIEW loads for a DESIGN_SYSTEM
    Then all components are available for rendering

  Scenario: PREVIEW renders JSX code
    Given the PREVIEW is loaded
    When JSX code is sent to the PREVIEW
    Then the components render correctly

  Scenario: PREVIEW updates when code changes
    Given the PREVIEW is displaying rendered content
    When the code changes
    Then the PREVIEW re-renders with the new content

  Scenario: PREVIEW shows placeholder when no DESIGN exists
    Given no JSX has been sent to the PREVIEW
    Then the PREVIEW shows a placeholder

  Scenario: DESIGN_SYSTEM renderer combines multiple FIGMA_FILEs
    Given a DESIGN_SYSTEM has 2 FIGMA_FILEs
    When the PREVIEW loads
    Then components from both files are available for rendering

  Scenario: ITERATION renderer uses the DESIGN's FIGMA_FILEs
    Given a DESIGN has ITERATIONs linked to a DESIGN_SYSTEM
    When the PREVIEW loads for an ITERATION
    Then all components from the DESIGN_SYSTEM are available

  Scenario: PREVIEW handles missing component gracefully
    Given the PREVIEW is loaded
    When JSX referencing a non-existent component is sent
    Then the PREVIEW shows an error without crashing

  Scenario: PREVIEW is accessible without authentication
    Given the PREVIEW URL is accessed without signing in
    Then the PREVIEW still loads and renders
