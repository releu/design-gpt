@design-improvement
Feature: Design Improvement via Chat
  Users can iteratively improve a generated design by sending chat messages.
  Each improvement creates a new Iteration with updated JSX. The chat panel
  shows the conversation history between the user, designer AI, and art director.
  Technical: POST /api/designs/:id/improve creates a new Iteration and
  ChatMessage, enqueues AiRequestJob. The AI receives full chat context
  (all previous iteration comments). Design goes through generating -> ready cycle again.

  Background:
    Given the user is logged in as "alice@example.com"
    And a design "My Design" exists with status "ready" and one completed iteration

  @critical @happy-path
  Scenario: Send an improvement request via chat
    Given the user is on the design page for "My Design"
    And the chat panel is visible showing "No messages yet" or previous messages
    When the user types "Make the header larger and change the color to blue" in the chat input
    And presses the "Send" button
    Then a POST request should be sent to /api/designs/:id/improve with the comment
    And the design status should change to "generating"
    And a new ChatMessage with author "user" should be created
    And a new Iteration should be created with the improvement comment
    And the preview should update when the new iteration's JSX is ready

  @critical @happy-path
  Scenario: Chat displays conversation history
    Given the design has the following chat messages:
      | author   | message                          |
      | user     | List top places in Belgrade      |
      | designer | Here is the design with...       |
      | user     | Make the title bigger            |
      | designer | Updated the title size...        |
    When the user views the chat panel
    Then all 4 messages should be displayed in order
    And user messages should be right-aligned with orange background
    And designer messages should be left-aligned with gray background
    And each message should show the author label ("You" for user, "Designer" for designer)

  @happy-path
  Scenario: Chat panel auto-scrolls to latest message
    Given the design has many chat messages that overflow the panel
    When a new message is added
    Then the chat panel should scroll to show the latest message

  @happy-path
  Scenario: Improvement triggers re-generation with full context
    Given the design has 2 previous iterations with comments "First prompt" and "Make it bigger"
    When the user sends improvement "Add more colors"
    Then the AI request should include the concatenated context of all 3 iteration comments
    And the schema should be rebuilt from the linked component libraries

  @happy-path
  Scenario: Chat send button is disabled while sending
    Given the user is on the design page
    When the user types a message and clicks "Send"
    Then the send button should become disabled
    And the textarea should become disabled
    When the request completes
    Then the send button should become enabled again

  @happy-path
  Scenario: Ctrl+Enter sends the message
    Given the user has typed an improvement in the chat input
    When the user presses Ctrl+Enter
    Then the message should be sent (same behavior as clicking Send)

  @edge-case
  Scenario: Empty message is not sent
    Given the chat input is empty
    Then the send button should appear disabled
    When the user clicks "Send"
    Then no request should be made

  @edge-case
  Scenario: Multiple rapid improvements queue correctly
    Given the user sends an improvement and the design is "generating"
    When the first generation completes
    And the user sends another improvement
    Then a new iteration should be created
    And the design should go through generating -> ready again

  @happy-path
  Scenario: Settings panel shows component configuration alongside chat
    Given the user is on the design page
    When the user clicks the "Settings" tab in the panel switcher
    Then the DesignSettings panel should appear showing the linked component libraries
    And each component should be listed in a left menu
    When the user selects a component
    Then the ComponentDetail view should show props, preview, configuration, and code
