@ds-rebuild
Feature: Design System Update Notification and Rebuild
  When a DESIGN_SYSTEM is synced and components change, existing DESIGNs
  linked to that system receive a notification in their chat. The user can
  rebuild the DESIGN to adapt to the updated component API.

  Background:
    Given the user is logged in as "alice@example.com"
    And the user has DESIGN_SYSTEM "Webmaster" with imported components
    And the user has DESIGN #100 linked to "Webmaster" with a generated PREVIEW

  # --- Notification ---

  Scenario: System message appears after DS sync completes
    When the DESIGN_SYSTEM "Webmaster" is synced successfully
    Then DESIGN #100 chat shows a system message "Design system was updated. Components may have changed."
    And the message has a "Rebuild design" button
    And the system message is visually distinct from user and AI messages

  Scenario: Multiple designs receive notifications
    Given the user also has DESIGN #200 linked to "Webmaster" with a generated PREVIEW
    When the DESIGN_SYSTEM "Webmaster" is synced successfully
    Then both DESIGN #100 and DESIGN #200 chat show the system message

  Scenario: Designs without iterations are not notified
    Given the user has DESIGN #300 linked to "Webmaster" with no ITERATIONs
    When the DESIGN_SYSTEM "Webmaster" is synced successfully
    Then DESIGN #300 does not receive a system message

  Scenario: Designs currently generating are not notified
    Given DESIGN #100 is currently generating
    When the DESIGN_SYSTEM "Webmaster" is synced successfully
    Then DESIGN #100 does not receive a system message

  Scenario: Designs linked to other DS are not notified
    Given the user has DESIGN #400 linked to DESIGN_SYSTEM "Other"
    When the DESIGN_SYSTEM "Webmaster" is synced successfully
    Then DESIGN #400 does not receive a system message

  Scenario: No notification on failed sync
    When the DESIGN_SYSTEM "Webmaster" sync fails with an error
    Then DESIGN #100 does not receive a system message

  # --- Rebuild ---

  @happy-path
  Scenario: Rebuild design after DS update
    Given the DESIGN_SYSTEM "Webmaster" was synced and DESIGN #100 has the rebuild notification
    When the user clicks "Rebuild design" on the system message
    Then the DESIGN begins regenerating
    And the "Rebuild design" button is disabled
    When the AI generation completes
    Then the PREVIEW updates with the rebuilt DESIGN
    And a new ITERATION is created
    And the rebuilt DESIGN preserves the layout and content of the previous version

  Scenario: Rebuild uses the previous iteration tree
    Given DESIGN #100 has a previous ITERATION with a JSON tree
    When the user triggers a rebuild
    Then the AI receives the previous tree JSON as context
    And the AI receives the updated component schema

  Scenario: Rebuild button is disabled after clicking
    Given the rebuild notification is visible in the chat
    When the user clicks "Rebuild design"
    Then the button shows "Rebuilding..." and is disabled
    And the user cannot click it again

  Scenario: Chat shows AI response after rebuild
    Given the user triggered a rebuild
    When the AI generation completes
    Then a new AI message appears in the chat
    And the message has "revert to this version" like other AI messages
