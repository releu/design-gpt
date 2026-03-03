@mode:serial
@timeout:600000
Feature: Component Library Browser UI
  Users can browse their imported component libraries, view individual
  components with live preview, inspect React code, and see configuration.
  Libraries page at /libraries, detail at /libraries/:id.

  Scenario: Setup library for browser tests
    Given I navigate to the home page
    And the app container is visible
    When I ensure the QA design system "QA Browser" is imported from Cubes
    Then the design system "QA Browser" should appear in the library selector
    And there are no console errors

  Scenario: Libraries list page displays library cards
    Given I navigate to the libraries page
    Then the libraries page should display at least one library card
    And each library card should show a name and status
    And there are no console errors

  Scenario: Navigate to library detail page
    Given I navigate to the libraries page
    When I click the first library card
    Then I should be navigated to a library detail page
    And the library detail page should display the library name
    And there are no console errors

  @critical
  Scenario: Component detail shows interactive props
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Browser"
    And I click a component that has variant props
    Then the Props section should list available props
    And variant props should have dropdown selects
    And there are no console errors

  Scenario: Changing props updates the live preview
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Browser"
    And I click a component that has variant props
    And I capture the current preview content
    And I change the first variant prop to a different value
    Then the preview iframe content should differ from the captured content
    And there are no console errors

  Scenario: Component detail shows React code
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Browser"
    And I click a component that has React code
    And I expand the React Code section
    Then the code section should display React source code
    And there are no console errors

  Scenario: Component detail shows configuration for root components
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Browser"
    And I find a root component in the menu
    Then the Configuration section should show root badge "yes"
    And there are no console errors

  Scenario: Overview shows library file counts
    Given I navigate to the home page
    And the app container is visible
    When I open the design system browser for "QA Browser"
    Then the Overview panel should show the design system name
    And the Overview should display file names with component counts
    And there are no console errors

  Scenario: Component preview page renders all components in grid
    Given I navigate to the home page
    And the app container is visible
    When I load the component preview page for "QA Browser"
    Then the preview page should display components in a grid layout
    And each component card should show a name and type badge
    And there are no console errors
