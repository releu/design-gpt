@design-improvement
Feature: Design Improvement via Chat
  Users can iteratively improve a generated design by sending chat messages.
  Each improvement creates a new Iteration with updated JSX. The chat panel
  shows the conversation history between the user, designer AI, and art director.
  Technical: POST /api/designs/:id/improve creates a new Iteration and
  ChatMessage, enqueues AiRequestJob. The AI receives full chat context
  (all previous iteration comments). Design goes through generating -> ready cycle again.
  UI reference: designer/05-design-page.md (chat panel detailed spec),
  designer/07-shared-components.md (chat panel component #9)

  Background:
    Given the user is logged in as "alice@example.com"
    And a design "My Design" exists with status "ready" and one completed iteration

  # --- Chat Panel UI ---

  @critical @happy-path
  Scenario: Chat panel displays with correct message styling
    Given the design has the following chat messages:
      | author   | message                          |
      | user     | List top places in Belgrade      |
      | designer | Here is the design with...       |
      | user     | Make the title bigger            |
      | designer | Updated the title size...        |
    When the user views the chat panel
    Then all 4 messages should be displayed in chronological order (oldest at top)
    And user messages should be left-aligned with no background bubble (plain text, --text-primary)
    And designer/AI messages should be right-aligned in a rounded bubble
    And designer/AI bubbles should have warm gray background (--bg-bubble-user), 16px border-radius
    And designer/AI bubbles should have max-width ~75% of panel width with 8px vertical / 16px horizontal padding
    And vertical gap between messages should be 8px

  @critical @happy-path
  Scenario: Chat messages are gravity-anchored to the bottom
    Given the design has only 2 chat messages
    When the user views the chat panel
    Then the messages should appear at the bottom of the panel
    And empty space should fill the area above the messages

  @critical @happy-path
  Scenario: Chat input bar styling
    Given the user is on the design page
    Then the chat input bar should be pinned to the bottom of the chat panel
    And the input bar should be pill-shaped (--radius-pill) with light gray background (--bg-chip-active)
    And the bar height should be approximately 44px
    And a text input should fill most of the bar width (transparent background, no border, 14px)
    And a solid black circle send button (~32px diameter) should appear at the right end
    And the send button should contain a white arrow/send icon

  # --- Send Behavior ---

  @critical @happy-path
  Scenario: Send an improvement request via chat
    Given the user is on the design page for "My Design"
    And the chat panel is visible
    When the user types "Make the header larger and change the color to blue" in the chat input
    And clicks the send button (black circle)
    Then a POST request should be sent to /api/designs/:id/improve with the comment
    And the design status should change to "generating"
    And a new ChatMessage with author "user" should be created
    And a new Iteration should be created with the improvement comment
    And the preview should update when the new iteration's JSX is ready

  @happy-path
  Scenario: Chat panel auto-scrolls to latest message
    Given the design has many chat messages that overflow the panel
    When a new message is added
    Then the chat panel should auto-scroll to show the latest message at the bottom

  @happy-path
  Scenario: Improvement triggers re-generation with full context
    Given the design has 2 previous iterations with comments "First prompt" and "Make it bigger"
    When the user sends improvement "Add more colors"
    Then the AI request should include the concatenated context of all 3 iteration comments
    And the schema should be rebuilt from the linked component libraries

  @happy-path
  Scenario: Send button is disabled while design is generating
    Given the design status is "generating"
    Then the send button should be visually disabled (lower opacity or hidden icon)
    And clicking the send button should have no effect
    When the design status changes to "ready"
    Then the send button should become enabled again

  @happy-path
  Scenario: Send button is disabled when input is empty
    Given the chat input is empty
    Then the send button should appear disabled (lower opacity or hidden icon)
    When the user types text into the input
    Then the send button should become enabled (full black circle)

  @happy-path
  Scenario: Ctrl+Enter or Cmd+Enter sends the message
    Given the user has typed an improvement in the chat input
    When the user presses Ctrl+Enter (or Cmd+Enter on Mac)
    Then the message should be sent (same behavior as clicking the send button)

  # --- Edge Cases ---

  @edge-case
  Scenario: Empty message is not sent
    Given the chat input is empty
    Then the send button should appear disabled
    When the user clicks the send button
    Then no request should be made

  @edge-case
  Scenario: Multiple rapid improvements queue correctly
    Given the user sends an improvement and the design is "generating"
    When the first generation completes
    And the user sends another improvement
    Then a new iteration should be created
    And the design should go through generating -> ready again

  @edge-case
  Scenario: Empty chat state for brand new design
    Given the design has no chat messages yet
    When the user views the chat panel
    Then the chat area should be empty
    And only the input bar should be visible at the bottom
    And messages should appear gravity-anchored to the bottom as they arrive

  # --- Settings Panel ---

  @happy-path
  Scenario: Settings panel replaces chat panel with two-pane component browser
    Given the user is on the design page
    When the user clicks "settings" in the mode selector
    Then the settings panel should replace the chat panel
    And the settings panel should have a left sidebar and right content area
    And the left sidebar should show:
      | section          | items                                      |
      | general          | overview                                   |
      | figma-file-name  | component names listed below, indented     |
    And the currently selected component should have a light gray highlight

  @happy-path
  Scenario: Settings panel shows component detail when component selected
    Given the user is on the design page with "settings" mode active
    When the user clicks on a component name in the left sidebar
    Then the right content area should show the ComponentDetail view:
      | element              | description                                    |
      | component name       | Bold text at top                               |
      | figma link           | "link to figma. sync with figma" links         |
      | props section        | VARIANT=dropdown, TEXT=input, BOOLEAN=checkbox  |
      | live preview         | Iframe rendering the component with current props |
      | configuration        | Root badge + allowed children (for root components) |

  @happy-path
  Scenario: Settings panel overview shows general design information
    Given the user is on the design page with "settings" mode active
    When the user clicks "overview" in the left sidebar
    Then the right content area should show the design system overview (name, linked files)
