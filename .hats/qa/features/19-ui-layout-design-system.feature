@ui @layout @design-system-tokens
Feature: UI Layout and Design System
  The application is a desktop-only web application using a warm monochrome
  design system. All pages share a common header bar and use one of four
  layout patterns with resizable panels separated by drag-handle dividers.
  Desktop-only: min 1200px wide x 600px tall, no mobile/tablet breakpoints.
  UI reference: designer/01-global-design-system.md,
  designer/02-layout-structures.md, designer/07-shared-components.md

  # --- Platform Constraints ---

  @critical
  Scenario: Desktop-only viewport with no page scroll
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And the page body should not scroll
    And the minimum viewport should be at least 1200px wide
    And there are no console errors

  # --- Color Palette ---

  Scenario: Warm monochrome color palette
    Given the user is logged in as alice
    When I navigate to the home page
    Then the page-level background should be warm gray
    And content panels should have white background
    And primary text should be near-black
    And there are no console errors

  # --- Typography ---

  Scenario: Typography uses system font stack
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And body text should use the system font stack
    And there are no console errors

  Scenario: Labels are lowercase throughout the application
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And labels in the UI should be lowercase
    And there are no console errors

  # --- Border Radius ---

  Scenario: Generous border radius system
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And content panels should have generous border radius
    And there are no console errors

  # --- Header Bar ---

  @critical
  Scenario: Header bar structure on every authenticated page
    Given the user is logged in as alice
    When I navigate to the home page
    Then the header bar should be visible
    And the header bar should contain the design selector
    And the header bar should contain the mode selector
    And the header bar should contain the more button
    And the header bar should contain the preview selector
    And there are no console errors

  Scenario: Mode selector toggle behavior
    Given the user is logged in as alice
    When I navigate to the home page
    Then the mode selector should show chat and settings pills
    And only one mode should be active at a time
    And there are no console errors

  Scenario: Preview selector toggle behavior
    Given the user is logged in as alice
    When I navigate to the home page
    Then the preview selector in the header should show phone, desktop, and code options
    And there are no console errors

  # --- Layout Patterns ---

  Scenario: Layout 1 - Three columns on home page
    Given the user is logged in as alice
    When I navigate to the home page
    Then the page should use a three-column layout below the header
    And the left column should contain the prompt panel
    And the center column should contain the design system panel
    And the right column should contain the preview frame
    And there are no console errors

  # --- Drag-Handle Dividers ---

  @critical
  Scenario: Resizable panels via drag-handle dividers
    Given the user is logged in as alice
    When I navigate to the home page
    Then columns should be separated by drag-handle dividers
    And there are no console errors

  # --- Module Panel Pattern ---

  Scenario: Module panels have consistent white card styling
    Given the user is logged in as alice
    When I navigate to the home page
    Then content panels should have white background
    And content panels should have generous border radius
    And there are no console errors

  # --- Interactive States ---

  Scenario: Disabled elements have reduced opacity
    Given the user is logged in as alice
    When I navigate to the home page
    Then the app container should be visible
    And there are no console errors

  # --- Scrolling ---

  Scenario: Panel-internal scrolling only, no page scroll
    Given the user is logged in as alice
    When I navigate to the home page
    Then the page body should not scroll
    And there are no console errors

  # --- Z-Index Layers ---

  Scenario: Modal overlay is above base content
    Given the user is logged in as alice
    When I navigate to the home page
    And the app container is visible
    When I click the new design system button
    Then the design system modal should be visible
    And the modal overlay should be above the base page content
    When I click the modal close button
    Then the design system modal should close
    And there are no console errors
