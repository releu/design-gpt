@figma-import
Feature: Figma Component Library Import
  Users import component libraries from Figma files. The system extracts
  component sets with variants, standalone components, icons (SVGs),
  generates React code, and runs visual diff comparisons.
  Technical: Figma API via Client, pipeline: Importer -> AssetExtractor ->
  ReactFactory -> VisualDiff. Sync is async via ComponentLibrarySyncJob.
  Status flow: pending -> discovering -> importing -> converting -> comparing -> ready | error.

  Background:
    Given the user is logged in as "alice@example.com"

  @critical @happy-path
  Scenario: Create a component library from a Figma URL
    When the user sends POST /api/component-libraries with url "https://www.figma.com/design/abc123/my-design-system"
    Then the response status should be 201
    And the response should contain an "id" field
    And a ComponentLibrary record should exist with status "pending"
    And the figma_file_key should be extracted as "abc123"

  @critical @happy-path
  Scenario: Trigger async sync from Figma
    Given a component library exists with id 1 and status "pending"
    When the user sends POST /api/component-libraries/1/sync
    Then the response should show status "pending"
    And a ComponentLibrarySyncJob should be enqueued

  @critical @happy-path
  Scenario: Full sync pipeline completes successfully
    Given a component library exists linked to a valid Figma file
    When the sync pipeline runs to completion
    Then the library status should be "ready"
    And ComponentSets should be created for each Figma component set
    And ComponentVariants should be created for each variant within component sets
    And standalone Components should be created for non-set components
    And SVG assets should be extracted and cached as FigmaAssets
    And react_code should be generated for all default variants
    And react_code_compiled should be generated for browser rendering
    And progress should show step 4/4 as complete

  @happy-path
  Scenario: Import progress is trackable via polling
    Given a component library sync is in progress
    When the user polls GET /api/component-libraries/:id
    Then the response should include a "progress" object
    And the progress should contain "step_number", "total_steps", and "message"
    And the progress updates as the pipeline advances through stages

  @happy-path
  Scenario: Duplicate Figma URL returns existing library
    Given a component library already exists with url "https://www.figma.com/design/abc123/my-design-system"
    When the user sends POST /api/component-libraries with the same url
    Then the response status should be 200
    And the response should return the existing library's id

  @happy-path
  Scenario: List user's component libraries
    Given the user owns 3 component libraries
    When the user sends GET /api/component-libraries
    Then the response should contain 3 libraries
    And each library should include id, name, figma_url, status, component counts

  @happy-path
  Scenario: View available libraries (own + public)
    Given the user owns 2 libraries
    And another user has 1 public library
    When the user sends GET /api/component-libraries/available
    Then the response should contain 3 libraries
    And each library should have an "is_own" flag

  @happy-path
  Scenario: Re-sync an existing library from Figma
    Given a component library exists with status "ready"
    When the user sends POST /api/component-libraries/:id/sync
    Then the library status should reset to "pending"
    And a new sync job should be enqueued
    And existing components should be updated rather than duplicated

  @happy-path
  Scenario: Figma conventions auto-detect root components
    Given a Figma file contains a component set named "Page #root"
    When the import pipeline completes
    Then the "Page" component set should have is_root set to true

  @happy-path
  Scenario: Figma conventions auto-detect allowed children via INSTANCE_SWAP
    Given a Figma component set has an INSTANCE_SWAP property with preferredValues ["Title", "Button"]
    When the import pipeline completes
    Then the component set should have allowed_children set to ["Title", "Button"]
    And the generated React code should contain "{props.children}" at the slot position

  @happy-path
  Scenario: List components for a component library shows a summary of the imported components
    Given a component library exists with status "ready"
    And the library contains 3 component sets and 2 standalone components
    When the user sends GET /api/component-libraries/:id/components
    Then the response should contain "component_sets" with 3 entries
    And the response should contain "components" with 2 entries
    And each component set should include name, node_id, is_root, allowed_children, variants, prop_definitions, react_name

  @edge-case
  Scenario: Import handles vector/icon components
    Given a Figma file contains a component that is purely vector-based
    When the import pipeline completes
    Then the component should be marked as is_vector true
    And an SVG asset should be cached for it

  @edge-case
  Scenario: Figma list component collapses repeated slots
    Given a Figma component set named "CardList #list" has 3 identical INSTANCE_SWAP nodes
    When the import pipeline completes
    Then the generated React code should contain a single "{props.children}"
    And allowed_children should contain the single allowed item type

  @error-handling
  Scenario: Sync fails gracefully on Figma API error
    Given a component library exists linked to an invalid Figma file key
    When the sync pipeline runs
    Then the library status should be "error"
    And the progress should contain an "error" message describing the failure

  @error-handling
  Scenario: Re-import a single component
    Given a component exists in a ready library
    When the user sends POST /api/components/:id/reimport
    Then the component should be re-imported from Figma
    And the response should include the updated component details

  @error-handling
  Scenario: Re-import a single component set
    Given a component set exists in a ready library
    When the user sends POST /api/component-sets/:id/reimport
    Then the component set should be re-imported from Figma
    And the response should include the updated variant count
