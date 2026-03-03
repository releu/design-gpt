@design-management
Feature: Design Management
  Users can list, view, rename, duplicate, delete, and export their designs.
  Technical: All routes scoped under /api/designs. Designs belong to User.
  Exports: PNG image, React project zip, Figma JSON tree.
  UI reference: designer/05-design-page.md (export menu, design selector dropdown),
  designer/07-shared-components.md (design selector #2, more button #5)

  Background:
    Given the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: List all user designs
    Given the user has 5 designs
    When the user sends GET /api/designs
    Then the response should contain 5 designs ordered by created_at descending
    And each design should include id, name, prompt, status, component_library_ids, has_jsx

  @critical @happy-path
  Scenario: View a specific design with iterations and chat
    Given a design "Travel Guide" exists with 2 iterations and 3 chat messages
    When the user sends GET /api/designs/:id
    Then the response should include the design details
    And the response should contain 2 iterations with their JSX and completion status
    And the response should contain 3 chat messages in order

  @happy-path
  Scenario: Design selector dropdown on the header bar
    Given the user has designs "Design A", "Design B"
    When the user visits any page
    Then the design selector should be a pill-shaped element in the header bar (left position)
    And it should show the current design name (or "new design" on the home page)
    And a small downward caret/chevron should appear to the right of the text
    And the selector should be ~160px minimum width, ~36px height
    When the user clicks the design selector
    Then a dropdown card should appear below (white, 16px border-radius, subtle shadow)
    And "(+) new design" should always be the first item
    And all user designs should be listed below, ordered by most recent
    And each item should be 14px text, ~36px row height, full-width hover highlight

  @happy-path
  Scenario: Selecting a design from the dropdown navigates to it
    Given the user is on a design page
    And the design selector dropdown is open
    When the user selects "Design A" from the dropdown
    Then the page should navigate to the Design A page
    When the user reopens the dropdown and selects "(+) new design"
    Then the user should be redirected to the home page

  @happy-path
  Scenario: Rename a design
    Given a design "Old Name" exists with id 10
    When the user sends PATCH /api/designs/10 with name "New Name"
    Then the response should confirm the name is "New Name"
    And the design name should be updated in the database

  @happy-path
  Scenario: Default design name is derived from prompt
    When the user creates a design with prompt "Create a dashboard for weather data in European capitals"
    Then the design name should default to the first 60 characters of the prompt

  @happy-path
  Scenario: Duplicate a design
    Given a design "Original" exists with iterations and linked libraries
    When the user sends POST /api/designs/:id/duplicate
    Then the response status should be 201
    And a new design should be created with name "Original (copy)"
    And the new design should have the same component libraries
    And the new design should have a copy of the last iteration's JSX
    And the new design status should be "ready"

  @happy-path
  Scenario: Delete a design
    Given a design exists with id 15
    When the user sends DELETE /api/designs/15
    Then the response status should be 204
    And the design should no longer exist in the database

  @happy-path
  Scenario: Export design as PNG image
    Given a design exists with a completed screenshot
    When the user sends GET /api/designs/:id/export_image
    Then the response should be a PNG image with content-type "image/png"

  @happy-path
  Scenario: Export design as React project zip
    Given a design exists with generated JSX
    When the user sends GET /api/designs/:id/export_react
    Then the response should be a zip file with content-type "application/zip"
    And the filename should end with "-react.zip"

  @happy-path
  Scenario: Export design as Figma JSON tree
    Given a design exists with a completed AI task and JSX
    When the user sends GET /api/designs/:id/export_figma
    Then the response should contain the component tree JSON
    And the response should include design_id, name, tree, jsx, and component_library_ids

  @happy-path
  Scenario: Export menu accessible via the more button
    Given the user is on a design page with a completed design
    Then a "..." more button should be visible in the header bar (center-right position)
    And the more button should display as three dots in primary text color with no background or border
    And the clickable area should be ~36x36px (larger than visible text)
    When the user clicks the "..." button
    Then a dropdown menu should appear anchored below the button
    And the dropdown should be a white card with 16px border-radius and subtle shadow
    And it should contain the following items (14px text, hover = light gray background):
      | action                  |
      | Download React project  |
      | Download image          |
      | Figma (alpha)           |

  @happy-path
  Scenario: Download React project from export menu
    Given the user is on a design page with a completed design
    And the export menu is open
    When the user clicks "Download React project"
    Then a GET request should be sent to /api/designs/:id/export_react
    And a zip file download should start

  @happy-path
  Scenario: Download image from export menu
    Given the user is on a design page with a completed design
    And the export menu is open
    When the user clicks "Download image"
    Then a GET request should be sent to /api/designs/:id/export_image
    And a PNG file download should start

  @happy-path
  Scenario: Figma export from export menu opens popup with pairing code
    Given the user is on a design page with a completed design
    And the export menu is open
    When the user clicks "Figma (alpha)"
    Then a popup should appear with the title "Figma (alpha)"
    And the popup should display a pairing code (secret)
    And a "Copy" button should be visible next to the code
    When the user clicks "Copy"
    Then the pairing code should be copied to the clipboard

  @happy-path
  Scenario: Image export captures at 2x pixel density
    Given a design exists with a completed preview
    When the user requests an image export via GET /api/designs/:id/export_image
    Then the exported image should be PNG format
    And the image should be captured at 2x pixel density (retina resolution)

  @error-handling
  Scenario: Export image returns 404 when no screenshot exists
    Given a design exists without a screenshot
    When the user sends GET /api/designs/:id/export_image
    Then the response status should be 404

  @error-handling
  Scenario: Export React returns 404 when no JSX exists
    Given a design exists without any iterations containing JSX
    When the user sends GET /api/designs/:id/export_react
    Then the response status should be 404

  @error-handling
  Scenario: Access another user's design returns 404
    Given a design belongs to a different user
    When the current user sends GET /api/designs/:id
    Then the response status should be 404
