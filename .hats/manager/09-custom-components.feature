@custom-components
Feature: Custom React Component Upload
  Users can upload custom React components to a DESIGN_SYSTEM.
  These are user-authored COMPONENTs (not imported from Figma) that extend
  the DESIGN_SYSTEM's capabilities.

  Background:
    Given the user is logged in as "alice@example.com"
    And the user owns a DESIGN_SYSTEM with imported components

  Scenario: Upload a custom React COMPONENT
    When the user uploads a custom COMPONENT with:
      | field                | value                                        |
      | name                 | CustomCard                                   |
      | description          | A custom card component                      |
      | react code           | a valid React function component              |
      | prop types           | title (string), size (enum: sm, md, lg)       |
    Then the COMPONENT is added to the DESIGN_SYSTEM
    And the COMPONENT is available for use in the PREVIEW

  Scenario: Upload a COMPONENT with boolean PROP type
    When the user uploads a COMPONENT with a boolean PROP "disabled"
    Then the PROP appears as a checkbox in the component detail

  Scenario: Update a custom COMPONENT
    Given a custom COMPONENT "CustomCard" exists
    When the user updates its React code
    Then the updated COMPONENT is available in the PREVIEW

  Scenario: Delete a custom COMPONENT
    Given a custom COMPONENT "CustomCard" exists
    When the user deletes the COMPONENT
    Then the COMPONENT is removed from the DESIGN_SYSTEM

  Scenario: Cannot upload to another user's DESIGN_SYSTEM
    Given a DESIGN_SYSTEM belongs to a different user
    When the current user tries to upload a custom COMPONENT to that DESIGN_SYSTEM
    Then the upload is rejected

  Scenario: Cannot modify another user's custom COMPONENT
    Given a custom COMPONENT belongs to a DESIGN_SYSTEM owned by another user
    When the current user tries to update or delete it
    Then the action is rejected
