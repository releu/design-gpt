@custom-components
Feature: Custom React Component Upload
  Users can upload custom React components to a component library.
  These are user-authored components (not imported from Figma) that extend
  the library's capabilities.
  Technical: POST /api/custom-components creates a Component with source "upload".
  JSX is compiled to a window-assigned wrapper. prop_types are converted to
  prop_definitions for schema compatibility. Supports CRUD operations.

  Background:
    Given the user is logged in as "alice@example.com"
    And the user owns a component library with id 1

  @critical @happy-path
  Scenario: Upload a custom React component
    When the user sends POST /api/custom-components with:
      | field                | value                                        |
      | name                 | CustomCard                                   |
      | description          | A custom card component                      |
      | react_code           | function CustomCard(props) { return ... }     |
      | component_library_id | 1                                            |
      | prop_types           | { "title": "string", "size": "enum:sm,md,lg" } |
    Then the response status should be 201
    And the response should include the component id, name, and status "imported"
    And the component should have react_code_compiled generated
    And prop_definitions should be built from prop_types:
      | prop   | definition_type | default |
      | title  | TEXT            |         |
      | size   | VARIANT         | sm      |

  @happy-path
  Scenario: Upload a component with boolean prop type
    When the user uploads a component with prop_types { "disabled": "boolean" }
    Then the prop_definitions should include "disabled" with type "BOOLEAN"

  @happy-path
  Scenario: Update a custom component
    Given a custom component "CustomCard" exists with id 5
    When the user sends PATCH /api/custom-components/5 with updated react_code
    Then the react_code_compiled should be regenerated
    And the response should confirm the update

  @happy-path
  Scenario: Delete a custom component
    Given a custom component "CustomCard" exists with id 5
    When the user sends DELETE /api/custom-components/5
    Then the response status should be 204
    And the component should be removed from the library

  @happy-path
  Scenario: Custom component with is_root and allowed_children
    When the user uploads a component with is_root true and allowed_children ["Title"]
    Then the component should be usable as a root in the AI schema
    And allowed_children should be ["Title"]

  @error-handling
  Scenario: Cannot upload to another user's library
    Given a component library belongs to a different user
    When the current user tries to upload a custom component to that library
    Then the response status should be 404

  @error-handling
  Scenario: Cannot modify another user's custom component
    Given a custom component belongs to a library owned by another user
    When the current user tries to update or delete it
    Then the response status should be 404
