@validation
Feature: Complex Figma File Compatibility
  Importing a real-world, complex Figma file (Cubes design system) must produce
  fully working components. This is a broad validation that the full pipeline
  holds up under real conditions.

  Scenario: All components render correctly after import
    Given the user has imported the Cubes Figma file
    Then every component and every VARIANT renders without errors
    And each component and VARIANT produces different PREVIEW HTML

  Scenario: All PROP types work for every component
    Given the user has imported the Cubes Figma file
    Then for every component, changing each PROP updates the PREVIEW correctly
    And the PREVIEW HTML reflects the changed PROP value

  Scenario: Visual diff passes for every default component state
    Given the user has imported the Cubes Figma file
    Then every component and VARIANT in its default state has a visual diff of 95% or above
