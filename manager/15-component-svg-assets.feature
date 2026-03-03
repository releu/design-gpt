@assets
Feature: Component SVG Assets
  Vector components and icons are exported as SVGs from Figma and cached
  as FigmaAssets. These SVGs are served via API endpoints and used inline
  in the component preview pages.
  Technical: FigmaAssets with asset_type "svg". Cached on first access.
  Served by ComponentsController#svg and component_set_svg.

  Background:
    Given a component library exists with vector components

  @happy-path
  Scenario: Serve cached SVG for a component
    Given a component has a cached SVG asset
    When the user sends GET /api/components/:id/svg
    Then the response should be SVG content with content-type "image/svg+xml"

  @happy-path
  Scenario: Fetch and cache SVG from Figma on first access
    Given a component has no cached SVG asset
    When the user sends GET /api/components/:id/svg
    Then the system should fetch the SVG from the Figma export API
    And cache it as a FigmaAsset for future requests
    And return the SVG content

  @happy-path
  Scenario: Serve SVG for a component set
    Given a component set has a cached SVG asset
    When the user sends GET /api/component-sets/:id/svg
    Then the response should be SVG content

  @edge-case
  Scenario: SVG not available from Figma
    Given Figma returns no SVG URL for a component
    When the user sends GET /api/components/:id/svg
    Then the response should contain a placeholder SVG comment

  @happy-path
  Scenario: Component HTML preview
    Given a component has HTML and CSS code
    When the user sends GET /api/components/:id/html_preview
    Then the response should be a standalone HTML page
    And the page should include the component's CSS and HTML

  @error-handling
  Scenario: HTML preview not available
    Given a component has no HTML code
    When the user sends GET /api/components/:id/html_preview
    Then the response status should be 404
