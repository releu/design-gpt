@mode:serial
@timeout:600000
Feature: Design Workflow

  Scenario: Import Figma file and create a design system
    Given I navigate to the home page
    And the app container is visible
    When I click "New design system"
    Then the design system modal should be visible
    When I add a Figma URL "https://www.figma.com/design/75U91YIrYa65xhYcM0olH5/example-lib"
    Then the Figma URL should appear in the pending list
    When I click "Import"
    Then the component browser should be visible within 5 minutes
    When I enter the design system name "Example"
    And I click "Page" in the component browser menu
    And I check the "Root component" checkbox
    And I add "Title" as an allowed child
    Then "Title" should appear in the allowed children list
    When I add "Text" as an allowed child
    Then "Text" should appear in the allowed children list
    When I click "Save"
    Then the design system modal should close
    And a design system should appear in the library selector
    And there are no console errors

  Scenario: Generate a design from a prompt
    Given I navigate to the home page
    And I had a previously added design system "Example"
    When I set the prompt to "What are the rivers in Belgrade?"
    And I select the design system "Example"
    And I take a screenshot "01-home-before-generate"
    And I click "Generate"
    Then I should be navigated to a design page
    And I should see the design page layout with switcher and preview
    And the preview should show the empty state
    And I take a screenshot "02-design-empty-state"
    When I wait for the design generation to complete
    Then the preview should display the generated design
    And I take a screenshot "03-design-generated-mobile"
    And the rendered preview should contain "Sava"
    And the rendered preview should contain "Danube"
    And there are no console errors

  Scenario: Preview component with editable props
    Given I navigate to the home page
    And the app container is visible
    When I open the design system "Example"
    And I click "Title" in the component browser menu
    Then the component preview iframe should be visible
    And the component preview should not be empty
    When I change the "Text" prop to "Hello World"
    Then the component preview should update
    And there are no console errors
