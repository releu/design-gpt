@visual-diff
Feature: Visual Diff Comparison
  After component import and React code generation, the system compares
  Figma screenshots with React-rendered screenshots to measure fidelity.
  Technical: VisualDiffJob runs after sync completes. Compares standalone
  components and component sets (via default variant). Results stored as
  match_percent on component/variant records. Screenshots and diff images
  stored as file paths.

  Background:
    Given the user is logged in as "alice@example.com"
    And a component library exists with status "ready"

  @happy-path
  Scenario: Visual diff results are available via API
    Given a component "Button" has completed visual diff with 92% match
    When the user sends GET /api/components/:id/visual_diff
    Then the response should include:
      | field                 | value |
      | match_percent         | 92    |
      | has_diff              | true  |
      | has_figma_screenshot  | true  |
      | has_react_screenshot  | true  |

  @happy-path
  Scenario: Retrieve diff image
    Given a component has a diff image generated
    When the user sends GET /api/components/:id/diff_image
    Then the response should be a PNG image

  @happy-path
  Scenario: Retrieve Figma screenshot
    Given a component has a Figma screenshot
    When the user sends GET /api/components/:id/screenshots/figma
    Then the response should be a PNG image

  @happy-path
  Scenario: Retrieve React screenshot
    Given a component has a React screenshot
    When the user sends GET /api/components/:id/screenshots/react
    Then the response should be a PNG image

  @happy-path
  Scenario: Match percentage displayed in component detail
    Given a component set "Card" has a default variant with 87% match
    When the user views the component detail for "Card"
    Then the match badge should display "87% match"
    And the badge should have a "medium" styling (between 50% and 80%)

  @edge-case
  Scenario: Component without visual diff shows no match data
    Given a component exists that has not been diffed yet
    When the user sends GET /api/components/:id/visual_diff
    Then match_percent should be null
    And has_diff, has_figma_screenshot, has_react_screenshot should be false

  @error-handling
  Scenario: Diff image not available returns 404
    Given a component has no diff image file
    When the user sends GET /api/components/:id/diff_image
    Then the response status should be 404

  @error-handling
  Scenario: Invalid screenshot type returns 400
    When the user sends GET /api/components/:id/screenshots/invalid
    Then the response status should be 400
    And the response should say "Unknown screenshot type"
