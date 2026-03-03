@api @custom-components
Feature: Custom React Component Upload API
  Users can upload custom React components to a component library.
  Supports CRUD operations and prop_types conversion to prop_definitions.

  @critical
  Scenario: Upload a custom React component with prop_types
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/customtest1/custom-lib"
    When I send an authenticated POST to "/api/custom-components" with body:
      """
      {
        "name": "CustomCard",
        "description": "A custom card component",
        "react_code": "function CustomCard(props) { return React.createElement('div', null, props.title); }",
        "component_library_id": "__LIBRARY_ID__",
        "prop_types": { "title": "string", "size": "enum:sm,md,lg" }
      }
      """
    Then the API response status should be 201
    And the API response body should contain field "id"

  Scenario: Upload a component with boolean prop type
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/customtest2/custom-bool-lib"
    When I send an authenticated POST to "/api/custom-components" with body:
      """
      {
        "name": "Toggle",
        "react_code": "function Toggle(props) { return React.createElement('div', null, String(props.disabled)); }",
        "component_library_id": "__LIBRARY_ID__",
        "prop_types": { "disabled": "boolean" }
      }
      """
    Then the API response status should be 201
    And the API response body should contain field "id"

  Scenario: Update a custom component
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/customtest3/custom-update-lib"
    And I have uploaded a custom component to the created library
    When I send an authenticated PATCH to the created custom component with updated code
    Then the API response status should be 200

  Scenario: Delete a custom component
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/customtest4/custom-delete-lib"
    And I have uploaded a custom component to the created library
    When I send an authenticated DELETE to the created custom component
    Then the API response status should be 204

  Scenario: Upload a component with is_root and allowed_children
    Given the user is logged in as alice
    And I have created a library with url "https://www.figma.com/design/customtest5/custom-root-lib"
    When I send an authenticated POST to "/api/custom-components" with body:
      """
      {
        "name": "PageRoot",
        "react_code": "function PageRoot(props) { return React.createElement('div', null, props.children); }",
        "component_library_id": "__LIBRARY_ID__",
        "is_root": true,
        "allowed_children": ["Title"]
      }
      """
    Then the API response status should be 201
    And the API response body should contain field "id"

  Scenario: Cannot upload to another user's library
    Given the user is logged in as alice
    When I send an authenticated POST to "/api/custom-components" with body:
      """
      {
        "name": "Test",
        "react_code": "function Test() { return null; }",
        "component_library_id": 999999
      }
      """
    Then the API response status should be 404

  Scenario: Cannot modify another user's custom component
    Given the user is logged in as alice
    When I send an authenticated PATCH to "/api/custom-components/999999" with body:
      """
      { "react_code": "function Hacked() { return null; }" }
      """
    Then the API response status should be 404
