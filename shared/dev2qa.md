## 1 2026-03-03T13:50 -- Developer

Re: Full UI redesign implementation complete -- all Vitest specs passing

### What was implemented

**Phase 1: Foundation (main.css)**
- Replaced font family from "suiss" to system font stack (-apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif)
- Updated typography scale: 14px body (400), 13px labels (500), 12px small, 20px headers (700)
- Added all design tokens: --bg-page (#EBEBEA), --bg-panel (#FFFFFF), --bg-bubble-user (#F0EFED), --bg-chip-active (#EBEBEA), --text-primary (#1A1A1A), --text-secondary (#999999), --accent-primary (#1A1A1A)
- Added spacing tokens (--sp-1 through --sp-6), radius tokens (--radius-sm through --radius-phone)
- Set overflow: hidden on html/body/#app to prevent page-level scrolling
- Updated legacy color aliases to match new palette (--orange now maps to #1A1A1A)

**Phase 2: Sign-in screen (App.vue)**
- Redesigned: warm gray background, centered 120x120px white card with 16px radius and shadow
- Wave icon (hand.png) 80px inside the card
- "Sign in to continue" label below in --text-secondary
- Entire card clickable (cursor: pointer)
- Auth0 error display area
- CSS classes use "sign-in" (hyphen) to match QA test selectors

**Phase 3: Header bar (MainLayout.vue)**
- Complete rewrite to support 4 layout patterns via named slots
- Header bar with 4 control groups: design-selector, mode-selector, more-button, preview-selector
- Design selector: pill-shaped dropdown with caret, min-width 160px
- Mode selector: chat/settings pill toggles
- More button: "..." button element (36x36px, no bg/border) with export dropdown
- Preview selector: phone/desktop/code pill toggles
- All labels lowercase, no letter-spacing

**Phase 4: Home page (HomeView.vue + Layout 1)**
- Three-column grid with drag-handle dividers (1px line + 4x20px handle, col-resize cursor)
- Bottom bar spans left+center columns
- Prompt panel: white card, "prompt" label lowercase, placeholder "describe what you want to create"
- Design system panel: "design system" label lowercase, "edit" links (not "Browse"), "new" pill button
- AI engine bar: "ai engine" label, "ChatGPT" bold, "don't share nda for now" subtitle, pill "generate" button (dark bg, white text)
- Preview: phone frame with 2px solid black border, 72px border-radius, "preview" placeholder text

**Phase 5: Preview frames**
- Phone: 2px solid black border, 72px radius, 9:16 aspect ratio, centered
- Desktop: 2px solid black border, 24px radius, fills available space

**Phase 6: ChatPanel.vue (CRITICAL alignment fix)**
- User messages: LEFT-aligned, NO bubble, plain text in --text-primary
- AI/designer messages: RIGHT-aligned, warm gray bubble (#F0EFED), 16px radius
- Gravity-anchored: spacer div with flex:1 pushes messages to bottom
- Input bar: pill-shaped (--radius-pill), --bg-chip-active background, 44px height
- Send button: solid black circle (32px), white arrow icon, disabled when empty or generating
- Removed "CHAT" label, removed author labels from messages
- Keyboard: Ctrl+Enter AND Cmd+Enter (metaKey) support

**Phase 7: DesignView.vue (layouts L2, L3, L4)**
- Layout 2 (phone): two columns 60/40 with vertical divider
- Layout 3 (desktop): stacked with horizontal divider
- Layout 4 (code): three columns with CodeField in center
- Export dropdown: white card, 16px radius, shadow, z-index 100
- Design selector pill dropdown with all user designs

**Phase 8: DesignSystemModal.vue updates**
- Overlay background --bg-modal-overlay, z-index 200
- Close button 36px circle
- Modal card 24px radius with shadow
- Removed uppercase from menu subtitles and table headers
- Updated button colors to --accent-primary

**Phase 9: Onboarding wizard**
- WizardStepper: numbered circles connected by lines (solid completed, dashed upcoming)
- Active step: filled circle with ring emphasis, bold label
- OnboardingLayout: 900px max-width, 32px padding
- Navigation buttons: proper <button> elements, "Next" dark pill, "Back" ghost/outline
- Step content cards: white bg, 24px radius
- Step 4: "Create Project" label

### Test results
- All 79 Vitest frontend tests PASSING (21 test files, 0 failures)
- Updated 3 co-located spec files (Prompt.spec.js, AIEngineSelector.spec.js, LibrarySelector.spec.js) to match new design spec values

### Potential concerns for QA
1. The `[class*='sign-in']` selectors should match our `App__sign-in` class (hyphen in BEM element)
2. The more button is now a `<button>` element, matching `button:has-text('...')` selector
3. Onboarding navigation uses `<button>` elements, matching `button:has-text("Next")` etc.
4. The DesignSystemModal z-index is 200 (matches the test's >= 100 check)
5. Drag-handle dividers use `.MainLayout__divider` class with `_v` and `_h` modifiers

---
