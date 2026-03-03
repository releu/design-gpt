@mode:serial
@timeout:600000
Feature: Design Improvement via Chat
  Users can iteratively improve a generated design by sending chat messages.
  Each improvement creates a new Iteration with updated JSX.
  CRITICAL: User messages are LEFT-aligned (no bubble, plain text).
  AI/designer messages are RIGHT-aligned in warm gray bubbles.
  UI reference: designer/05-design-page.md, designer/07-shared-components.md

  # --- Setup ---

  @critical
  Scenario: Setup design for improvement testing
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Improve" is imported from Cubes
    And I set the prompt text to "Create a simple page about parks in Amsterdam"
    And I select design system "QA Improve"
    And I click the generate button
    Then I should be navigated to a design page
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    And the preview iframe content should not be empty
    And there are no console errors

  # --- Chat Message Styling (CRITICAL FIX) ---

  @critical
  Scenario: Chat messages have correct alignment and styling
    Given I am on the current design page
    And the chat panel is visible
    Then the chat panel should display at least 2 messages
    And user messages should be left-aligned with no background bubble
    And designer messages should be right-aligned with warm gray bubble
    And there are no console errors

  @critical
  Scenario: Chat messages are gravity-anchored to the bottom
    Given I am on the current design page
    And the chat panel is visible
    Then the messages should appear at the bottom of the chat panel
    And there are no console errors

  # --- Chat Input Bar ---

  @critical
  Scenario: Chat input bar has pill shape with send button
    Given I am on the current design page
    Then the chat input bar should be pill-shaped at the bottom of the chat panel
    And the chat input should have a text field
    And a solid black circle send button should be at the right end of the input bar
    And there are no console errors

  # --- Send Behavior ---

  @critical
  Scenario: Send an improvement request via chat
    Given I am on the current design page
    And the chat panel is visible
    When I type "Make the title larger and add more details" in the chat input
    And I click the chat send button
    Then the chat input should be cleared
    When I wait for the design to finish generating
    Then the preview iframe should be visible
    And the preview iframe content should not be empty
    And there are no console errors

  Scenario: Chat displays conversation history with both authors
    Given I am on the current design page
    Then the chat panel should display at least 2 messages
    And the chat messages should include both user and designer messages
    And there are no console errors

  Scenario: Send button is disabled when input is empty
    Given I am on the current design page
    Then the chat send button should be disabled when input is empty
    And there are no console errors

  Scenario: Send button is disabled while generating
    Given I am on the current design page
    And the chat panel is visible
    When I type "Make the background darker" in the chat input
    And I click the chat send button
    Then the chat send button should be disabled during generation
    And there are no console errors

  Scenario: Ctrl+Enter or Cmd+Enter sends the message
    Given I am on the current design page
    When I type "Add a footer section" in the chat input
    And I press Ctrl+Enter in the chat input
    Then the chat input should be cleared
    And there are no console errors

  Scenario: Chat panel auto-scrolls to latest message
    Given I am on the current design page
    And the chat panel is visible
    Then the chat panel should be scrolled to the bottom
    And there are no console errors

  # --- Settings Panel ---

  Scenario: Settings panel replaces chat panel with two-pane browser
    Given I am on the current design page
    When I click the Settings tab in the panel switcher
    Then the design settings panel should be visible
    And there are no console errors

  Scenario: Mode selector shows chat and settings as mutually exclusive
    Given I am on the current design page
    Then the mode selector should show chat and settings pills
    And only one mode should be active at a time
    And there are no console errors
