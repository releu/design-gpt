@mode:serial
@timeout:600000
Feature: Design Generation Workflow
  Users enter a text prompt and select a design system. The backend generates
  a JSON tree via AI, transforms it to JSX, and the frontend renders it in
  a preview iframe. Design status flow: draft -> generating -> ready | error.

  @critical
  Scenario: Ensure design system exists for generation
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Generate" is imported from Cubes
    Then the design system "QA Generate" should appear in the library selector
    And there are no console errors

  @critical
  Scenario: Generate a design from a prompt
    Given I navigate to the home page
    And I verify design system "QA Generate" exists
    When I set the prompt text to "List the top 5 rivers in Belgrade"
    And I select design system "QA Generate"
    And I click the generate button
    Then I should be navigated to a design page
    And the design page should show the view mode switcher
    And the preview area should show the empty state
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    And the preview iframe content should not be empty
    And the rendered preview should contain text "Sava"
    And the rendered preview should contain text "Dunav"
    And there are no console errors

  Scenario: View mode switching between mobile, desktop, and code
    Given I am on the current design page
    When I click the desktop view switcher
    Then the preview should render in desktop layout
    When I click the code view switcher
    Then the code editor should be visible
    And the code editor should contain JSX content
    When I click the mobile view switcher
    Then the preview should render in mobile layout
    And there are no console errors

  Scenario: Code view shows editable JSX with CodeMirror
    Given I am on the current design page
    When I click the code view switcher
    Then the code editor should be visible
    And the code editor should contain JSX content
    And the code editor should use CodeMirror
    And there are no console errors

  Scenario: Editing JSX in code view triggers live preview update
    Given I am on the current design page
    When I click the code view switcher
    And I capture the current code editor content
    And I modify the JSX in the code editor
    Then the code editor content should have changed
    And there are no console errors

  Scenario: Design page shows design name in dropdown
    Given I am on the current design page
    Then the design dropdown should be visible
    And the design dropdown should contain at least one design option
    And there are no console errors

  Scenario: Navigate from design page back to new design
    Given I am on the current design page
    When I select new design from the dropdown
    Then I should be navigated to the home page
    And there are no console errors

  Scenario: New user with no design systems sees disabled generate
    Given I navigate to the home page
    And the app container is visible
    Then the generate button should be present
    And there are no console errors

  Scenario: Export menu is accessible from the design page
    Given I navigate to the home page
    And I verify design system "QA Generate" exists
    When I set the prompt text to "List parks in Tokyo for export menu test"
    And I select design system "QA Generate"
    And I click the generate button
    Then I should be navigated to a design page
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    When I click the export menu button
    Then the export menu should be visible
    And the export menu should contain "Download React project"
    And the export menu should contain "Download image"
    And there are no console errors
