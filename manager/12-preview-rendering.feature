@preview-rendering
Feature: Preview Rendering
  The preview component renders generated JSX inside an iframe using a
  renderer page that includes React, ReactDOM, Babel, and all compiled
  component code. Communication happens via postMessage.
  Technical: Preview.vue wraps an iframe pointed at the renderer URL.
  Renderer is served by /api/component-libraries/:id/renderer,
  /api/design-systems/:id/renderer, or /api/iterations/:id/renderer.
  The renderer sends a "ready" message; the frontend responds with
  { type: "render", jsx: "..." }. Babel compiles JSX at runtime.

  Background:
    Given a component library exists with compiled React components

  @critical @happy-path
  Scenario: Renderer page loads with all dependencies
    When the renderer page is loaded at /api/component-libraries/:id/renderer
    Then the HTML should include React 18 UMD script
    And the HTML should include ReactDOM 18 UMD script
    And the HTML should include Babel standalone script
    And all component code (react_code_compiled) should be injected into the page
    And a postMessage listener should be set up for "render" messages
    And a "ready" message should be sent to the parent window

  @critical @happy-path
  Scenario: Preview iframe receives and renders JSX
    Given the preview iframe has loaded and sent the "ready" message
    When the parent sends postMessage { type: "render", jsx: "<Page><Title text=\"Hello\" /></Page>" }
    Then the iframe should compile the JSX via Babel
    And render the component tree inside the #root element
    And the rendered content should contain "Hello"

  @happy-path
  Scenario: Design system renderer combines multiple libraries
    Given a design system has 2 component libraries
    When the renderer at /api/design-systems/:id/renderer is loaded
    Then components from both libraries should be available
    And JSX using components from either library should render correctly

  @happy-path
  Scenario: Iteration renderer uses the design's libraries
    Given a design has iterations linked to component libraries
    When the renderer at /api/iterations/:id/renderer is loaded
    Then all component code from the design's libraries should be present

  @happy-path
  Scenario: Preview component re-renders when code prop changes
    Given the Preview component is mounted with initial JSX code
    When the code prop changes to new JSX
    Then a new postMessage should be sent to the iframe with the updated JSX
    And the iframe should re-render with the new content

  @happy-path
  Scenario: Mobile layout applies rounded iframe styling
    Given the Preview component is rendered with layout "mobile"
    Then the iframe should have border-radius of 72px (mobile phone shape)

  @happy-path
  Scenario: Desktop layout applies standard iframe styling
    Given the Preview component is rendered with layout "desktop"
    Then the iframe should have border-radius of 24px (standard card)

  @edge-case
  Scenario: Renderer handles missing component gracefully
    Given the renderer is loaded
    When JSX referencing a non-existent component "FooBar" is sent
    Then the iframe should show a rendering error
    And the error should not crash the entire renderer

  @edge-case
  Scenario: Renderer serves without authentication
    Given the renderer URL is accessed without an Authorization header
    Then the renderer page should still load (no auth required)
    And all component code should be present
