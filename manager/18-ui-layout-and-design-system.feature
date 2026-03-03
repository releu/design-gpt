@ui @layout @design-system-tokens
Feature: UI Layout and Design System
  The application is a desktop-only web application using a warm monochrome
  design system. All pages share a common header bar and use one of four
  layout patterns with resizable panels separated by drag-handle dividers.
  Technical: Vue 3 Options API, SCSS in SFCs, BEM naming.
  Desktop-only: min 1200px wide x 600px tall, no mobile/tablet breakpoints.
  UI reference: designer/01-global-design-system.md,
  designer/02-layout-structures.md, designer/07-shared-components.md

  # --- Platform Constraints ---

  @critical @happy-path
  Scenario: Desktop-only viewport
    Given the application is loaded in a browser
    Then the minimum supported viewport should be 1200px wide and 600px tall
    And no mobile or tablet breakpoints should exist
    And the page itself should not scroll -- all scrolling happens inside individual panels

  # --- Color Palette ---

  @happy-path
  Scenario: Warm monochrome color palette
    Given any page in the application is loaded
    Then the page-level background should be warm gray (#EBEBEA, --bg-page)
    And all content panels should have white background (#FFFFFF, --bg-panel)
    And text inputs and textareas should have white background (#FFFFFF, --bg-input)
    And primary text should be near-black (#1A1A1A, --text-primary)
    And secondary/placeholder text should be medium gray (#999999, --text-secondary)
    And the palette should be intentionally neutral with no brand accent color

  @happy-path
  Scenario: Chat bubble colors match design
    Given the chat panel is visible with messages
    Then AI/designer message bubbles should have warm gray background (#F0EFED, --bg-bubble-user)
    And user messages should have no background (transparent)
    And active/selected chips should have light gray fill (#EBEBEA, --bg-chip-active)
    And inactive chips should have transparent background

  # --- Typography ---

  @happy-path
  Scenario: Typography scale
    Given any page in the application is loaded
    Then the font-family should be "-apple-system, BlinkMacSystemFont, Inter, Segoe UI, Roboto, sans-serif"
    And body text should be 14px weight 400
    And labels (module labels, section headers) should be 13px weight 500
    And small/caption text (placeholders, descriptions) should be 12px weight 400
    And code text should be 13px weight 400 monospace
    And all labels should be lowercase (e.g. "new design", "chat", "settings", "phone")
    And no uppercase or letter-spacing transforms should be applied anywhere

  # --- Spacing ---

  @happy-path
  Scenario: 8px grid spacing system
    Given any page in the application is loaded
    Then spacing should follow an 8px grid:
      | token  | value | usage                                         |
      | sp-1   | 4px   | Tight internal padding (inside chips)         |
      | sp-2   | 8px   | Default internal padding, gap between items   |
      | sp-3   | 16px  | Panel padding, gap between components         |
      | sp-4   | 24px  | Larger section spacing                        |
      | sp-5   | 32px  | Outer margin around page layout container     |
      | sp-6   | 48px  | Extra-large spacing (modal content from edges)|
    And the gap between adjacent panels should be approximately 16px of visible page background

  # --- Border Radius ---

  @happy-path
  Scenario: Generous border radius system
    Given any page in the application is loaded
    Then small elements (chips, badges) should use 8px border-radius (--radius-sm)
    And cards, panels, inputs, buttons, chat bubbles should use 16px (--radius-md)
    And large containers, modals should use 24px (--radius-lg)
    And pill-shaped elements (header toggles, generate button) should use 9999px (--radius-pill)
    And the phone preview frame should use 72px (--radius-phone)
    And the design should avoid sharp corners entirely

  # --- Shadows and Borders ---

  @happy-path
  Scenario: Minimal shadows and borders
    Given any page in the application is loaded
    Then content panels should have no visible box-shadow (elevation via bg contrast only)
    And the design system modal should have subtle shadow (0 4px 24px rgba(0,0,0,0.08))
    And buttons should have no shadow
    And most panels should have no visible border (relying on background contrast)
    And the preview frame (phone/desktop) should have 2px solid black border

  # --- Header Bar ---

  @critical @happy-path
  Scenario: Header bar structure on every page
    Given any authenticated page in the application is loaded
    Then a header bar should be present at the top (~48px height)
    And the header should have transparent background (page background shows through)
    And it should contain four control groups distributed with space-between:
      | group          | position      | content                                      |
      | design selector| left          | Pill with current design name + dropdown caret|
      | mode selector  | center-left   | "chat" and "settings" pill toggles            |
      | more button    | center-right  | "..." text (three dots), no border/background |
      | preview selector| right        | "phone", "desktop", "code" pill toggles       |

  @happy-path
  Scenario: Mode selector toggle behavior
    Given the header bar is visible
    Then the mode selector should have two pill-shaped options: "chat" and "settings"
    And exactly one pill should be active at a time (mutually exclusive)
    And the active pill should have light gray fill (--bg-chip-active) and bold text
    And the inactive pill should have transparent background and normal text
    And "chat" should be active by default
    And the gap between pills should be 4px (--sp-1)
    And each pill should be ~36px height with ~8px 16px padding

  @happy-path
  Scenario: Preview selector toggle behavior
    Given the header bar is visible
    Then the preview selector should have three pill-shaped options: "phone", "desktop", "code"
    And exactly one should be active at a time (mutually exclusive)
    And styling should match the mode selector (active=filled, inactive=transparent)
    And "phone" should be active by default
    And selecting "phone" should trigger Layout 2 with phone bezel preview
    And selecting "desktop" should trigger Layout 3 with desktop card preview
    And selecting "code" should trigger Layout 4 with code editor + phone preview

  # --- Layout 1: Three Columns + Bottom Bar (Home / New Design) ---

  @happy-path
  Scenario: Layout 1 structure on home page
    Given the user is on the home page
    Then the layout should have three top columns (~33% each) below the header
    And a bottom bar spanning the left + center columns (not the preview column)
    And the right column (preview) should extend full height from header to bottom of viewport
    And all panels should be white cards with 24px border-radius and 16px padding

  # --- Layout 2: Two Columns (Phone Preview + Chat) ---

  @happy-path
  Scenario: Layout 2 structure on design page with phone preview
    Given the user is on a design page with "phone" preview selected
    Then the layout should have two columns: left (~60% chat), right (~40% preview)
    And a vertical drag-handle divider should separate the columns

  # --- Layout 3: Stacked (Desktop Preview + Chat) ---

  @happy-path
  Scenario: Layout 3 structure on design page with desktop preview
    Given the user is on a design page with "desktop" preview selected
    Then the chat panel should take full width with reduced height (top portion)
    And the desktop preview should take full width below the chat
    And a horizontal drag-handle divider should separate chat from preview

  # --- Layout 4: Three Columns (Code View) ---

  @happy-path
  Scenario: Layout 4 structure on design page with code view
    Given the user is on a design page with "code" preview selected
    Then the layout should have three columns: left (~25% chat), center (~42% code), right (~33% preview)
    And two vertical drag-handle dividers should separate the columns

  # --- Drag-Handle Dividers ---

  @critical @happy-path
  Scenario: Resizable panels via drag-handle dividers
    Given any layout with multiple panels
    Then panels should be separated by 16px gaps containing drag-handle dividers
    And each divider should be a thin 1px line (--accent-divider, #E0E0E0)
    And a small bar indicator (~20px wide, ~4px tall) should be centered on the divider line
    And the cursor should change to col-resize (vertical dividers) or row-resize (horizontal dividers) on hover
    And dragging a divider should redistribute the percentage widths/heights of adjacent panels

  # --- Module Panel Pattern ---

  @happy-path
  Scenario: Module panel consistent styling
    Given any content panel in the application (prompt, design system, chat, settings, etc.)
    Then the panel should follow the module pattern:
      | property     | value                                    |
      | background   | white (--bg-panel)                       |
      | border-radius| 24px (--radius-lg)                       |
      | padding      | 16px (--sp-3)                            |
      | border       | none                                     |
      | shadow       | none                                     |
    And a label should appear at the top-left (13px, weight 500, --text-primary)
    And the label should have 8px margin-bottom before content

  # --- Interactive States ---

  @happy-path
  Scenario: Interactive hover and active states
    Given interactive elements are present on the page
    Then pill/chip elements should darken slightly on hover and fill with --bg-chip-active when selected
    And dark buttons should lighten slightly on hover (e.g. #333) and scale down slightly on press
    And disabled elements should have reduced opacity (0.5) and no pointer cursor
    And text inputs should show a subtle border or outline when focused
    And link text ("edit", "open", "remove") should underline on hover

  # --- Animation Defaults ---

  @happy-path
  Scenario: Transition defaults
    Given any animated element in the application
    Then panel transitions should use 150ms ease for opacity and transform
    And chip/toggle selection should use 100ms ease for background-color
    And modal open/close should use 200ms ease for opacity + slight scale
    And page navigations (Vue Router) should be instant with no transition animation

  # --- Scrolling ---

  @happy-path
  Scenario: Panel-internal scrolling only
    Given any page in the application is loaded
    Then the page body should not scroll (overflow: hidden on the viewport)
    And the chat panel should scroll vertically with auto-scroll to bottom on new messages
    And the component tree sidebar should scroll vertically if the list overflows
    And the code editor should handle its own internal scrolling via CodeMirror
    And the preview iframe content should scroll internally (not the frame)

  # --- Z-Index Layers ---

  @happy-path
  Scenario: Z-index layering
    Given overlapping UI elements are present
    Then the base layer (page, panels) should be at z-index 0
    And dropdown menus (design selector, export menu) should be at z-index 100
    And the modal overlay should be at z-index 200
    And the modal content card should be at z-index 201
    And toast notifications (if any) should be at z-index 300
