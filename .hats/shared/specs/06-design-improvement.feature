@design-improvement
Feature: Design Improvement via Chat
  Users can iteratively improve a generated DESIGN by sending chat messages.
  Each improvement creates a new ITERATION with updated JSX. The chat panel
  shows the conversation history between the user and the AI.

  Background:
    Given the user is logged in as "alice@example.com"
    And the user has DESIGN #100 with a generated PREVIEW

  Scenario: Chat panel displays conversation history
    Given the DESIGN has chat messages from the user and AI
    When the user views the chat panel
    Then all messages are displayed in chronological order
    And user messages are visually distinct from AI messages

  @happy-path
  Scenario: Send an improvement request via chat
    Given the user is on the design page for DESIGN #100
    When the user types "Make the header larger and change the color to blue" in the chat input
    And sends the message
    Then the message appears in the chat
    And the DESIGN begins regenerating
    And the PREVIEW updates when the new ITERATION is ready

  Scenario: Chat auto-scrolls to latest message
    Given the DESIGN has many chat messages
    When a new message is added
    Then the chat scrolls to show the latest message

  Scenario: Improvement uses full conversation context
    Given the DESIGN has previous ITERATIONs
    When the user sends a new improvement
    Then the AI receives the full context of all previous messages

  Scenario: Send button is disabled while generating
    Given the DESIGN is being generated
    Then the user cannot send a new message
    When the generation completes
    Then sending is enabled again

  Scenario: Send button is disabled when input is empty
    Given the chat input is empty
    Then the user cannot send a message
    When the user types text
    Then sending becomes enabled

  Scenario: Ctrl+Enter or Cmd+Enter sends the message
    Given the user has typed an improvement
    When the user presses Ctrl+Enter (or Cmd+Enter on Mac)
    Then the message is sent

  Scenario: Empty message is not sent
    Given the chat input is empty
    When the user tries to send
    Then nothing happens

  Scenario: Multiple improvements in sequence
    Given the user sends an improvement and the DESIGN is generating
    When the generation completes
    And the user sends another improvement
    Then a new ITERATION is created

  # --- Settings Panel ---

  Scenario: Settings panel shows component browser
    Given the user is on the design page
    When the user switches to "settings" mode
    Then the settings panel replaces the chat panel
    And the user can browse components and view their details

  Scenario: Settings panel overview shows DESIGN_SYSTEM info
    Given the user is in "settings" mode
    When the user clicks "overview"
    Then the DESIGN_SYSTEM overview is shown
