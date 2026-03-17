Feature: Image Workflow
  The image workflow spans three layers: Figma convention (`#image` tag marks
  image placeholder components), web preview rendering (div + CSS background-image
  fetched via the image render endpoint), and Figma plugin export (IMAGE fills
  applied to component instances).

  # --- Figma Convention ---

  Scenario: Components tagged #image are detected during import
    Given a FIGMA_FILE contains a component with "#image" in its description
    And the component is a plain rectangle frame with a background fill, no children, and no corner radius
    When the import completes
    Then the component is marked as an IMAGE component
    And IMAGE components are excluded from SLOT ALLOWED_CHILDREN lists

  Scenario: Invalid #image component structure is imported with validation warnings
    Given a FIGMA_FILE contains a component with "#image" in its description
    But the component has children, text layers, component properties, or corner radius
    When the import completes
    Then the component is marked as an IMAGE component
    And the component has validation warnings describing each structural issue
    And components with validation warnings are excluded from the AI schema

  # --- Image Render Endpoint ---

  Scenario: Image render endpoint returns proxied image bytes
    When the user requests GET /api/images/render?prompt=modern+office
    Then the response status is 200
    And the Content-Type is image/*
    And the Access-Control-Allow-Origin header is *

  Scenario: Blank prompt returns 400
    When the user requests GET /api/images/render?prompt=
    Then the response status is 400

  Scenario: Cache returns same image for repeated queries
    When the user requests GET /api/images/render?prompt=sunset+beach
    And the user requests GET /api/images/render?prompt=sunset+beach again
    Then both responses return identical image bytes

  Scenario: Image search requires authentication
    When an unauthenticated user requests GET /api/images?q=office
    Then the response status is 401

  # --- Web Preview Rendering ---

  Scenario: Design preview renders image component with background-image
    Given the user has a design with an image component
    When the design preview loads
    Then the preview contains a div with backgroundImage style
    And the preview does not contain an img tag for the image component
    And the background-image URL points to the image render endpoint

  # --- Figma Plugin Export ---

  Scenario: Figma plugin applies IMAGE fills to image components
    Given a design tree contains image component instances
    When the Figma plugin processes the export
    Then image components receive IMAGE fills from the image search API
    And the fill replaces the component's existing fills
