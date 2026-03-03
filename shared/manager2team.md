# Manager to Team

## 1 2026-03-03T12:00 -- Manager

Re: Major spec update -- aligned all feature specs with designer's 8 design description files

After reviewing all 8 design descriptions (01-global-design-system through 08-onboarding-wizard) against the 17 existing feature specs, I have updated 8 specs and created 1 new spec. Here is what changed and why.

### CRITICAL FIX

**`06-design-improvement.feature`** -- Chat message alignment was WRONG. The old spec said "user messages right-aligned with orange background, designer messages left-aligned with gray background." The designs show the OPPOSITE: user messages are LEFT-aligned with NO bubble (plain text), and AI/designer messages are RIGHT-aligned in a warm gray bubble (#F0EFED, 16px radius). This has been corrected. All chat UI detail has been added: pill-shaped input bar (~44px, --radius-pill, light gray bg), solid black circle send button (~32px), gravity-anchored messages (empty space above), Cmd+Enter for Mac, send button disabled states (empty input AND during generation).

### Updated Files (8)

1. **`01-authentication.feature`** -- Added sign-in screen UI detail from design 03: wave icon on centered white card (~120x120px, 16px radius, shadow), warm gray background, "Sign in to continue" label. Added click-to-login scenario. Added Auth0 error handling scenario. Updated authenticated-user scenario to check for header bar, prompt panel, design system panel, AI engine bar, and preview frame (not just "prompt area" and "design system selector").

2. **`03-figma-import.feature`** -- Added UI scenarios from design 06 (modal overview pane): "add figma file" input with "add" button, import progress visible in modal, "open" and "remove" links on file list items, "sync with figma" action link, sync failure error display in modal.

3. **`04-design-system-management.feature`** -- Major rewrite. Added full-screen modal overlay structure: --bg-modal-overlay background, close (x) button in top-left of overlay (~36px circle), centered modal card (~65% x ~70% viewport, 24px radius, shadow). Added two-pane layout detail: left navigation sidebar (~35%) with general/overview and Figma-file-organized component tree, right content area (~65%). Replaced "clicks Save" with auto-save on blur/close. Added close-on-overlay-click. Added per-component Figma link and sync. Added ComponentDetail sections: name (16px bold), type badge, status badge, props with type-dependent controls, live preview iframe, React code (read-only CodeMirror), configuration (read-only root + children).

4. **`05-design-generation.feature`** -- Significant expansion. Added home page three-column layout (Layout 1) with exact proportions and drag-handle dividers. Added prompt panel detail (white card, 24px radius, "prompt" label, placeholder text). Added design system panel detail (library list with "edit" links, "new" button). Added AI engine bar detail (ChatGPT label, subtitle, pill-shaped generate button with dark bg). Added all four layout modes for the design page: Layout 2 (phone=two columns 60/40), Layout 3 (desktop=stacked with horizontal divider), Layout 4 (code=three columns 25/42/33 with code editor + phone preview). Updated design selector dropdown detail. Added generating state with disabled send button. Fixed placeholder text from "Generated design will appear here" to "preview" (matching designs).

5. **`07-design-management.feature`** -- Added design selector pill shape detail (caret/chevron, ~160px min width, ~36px height), dropdown styling (white card, 16px radius, shadow, items 14px with hover highlight, "(+) new design" always first). Added more button detail (three dots, no border/bg, ~36x36px clickable area, center-right position). Added export dropdown styling (white card, 16px radius, shadow).

6. **`08-component-library-browser.feature`** -- Added shared ComponentDetail view structure used across three contexts (modal, settings panel, library detail page). Added component header detail: name 16px bold, "link to figma" link, "sync with figma" action, type badge (pill), status badge with color coding. Added live preview iframe detail (1px solid border, full width, ~200-300px height). Added React code section (read-only CodeMirror, monospace, JSX highlighting). Clarified configuration is read-only (set by Figma conventions).

7. **`11-onboarding-wizard.feature`** -- Added page layout detail (warm gray bg, centered ~900px container, 32px padding). Added stepper visual detail: numbered circles connected by horizontal lines, completed=filled circle + solid line, active=filled with ring emphasis + bold label, upcoming=outline circle + dashed line. Added navigation button styling: "Next"=dark pill, "Back"=ghost/outline (hidden on Step 1), "Create Project" label on Step 4. Added step content white card (24px radius, 24px padding). Added Step 2 row detail (checkbox, name, status badge, component count, import input). Added Step 3 grouping (Component Sets section + Standalone Components section with counts). Added Step 4 tag-based UI for children (pill tags with [+] add and (x) remove).

8. **`12-preview-rendering.feature`** -- Added phone frame details: 2px solid black border, ~9:16 portrait aspect ratio, horizontal/vertical centering in column, notch indicator extending to column divider. Added desktop frame: 2px solid black border, 24px radius, fills available space. Fixed placeholder text to "preview" (was inconsistent). Added internal scrolling note.

### New File (1)

9. **`18-ui-layout-and-design-system.feature`** -- New spec covering cross-cutting UI patterns not previously captured:
   - Desktop-only constraint (min 1200x600, no mobile breakpoints)
   - Warm monochrome color palette (all tokens: --bg-page, --bg-panel, --text-primary, etc.)
   - Typography scale (14px body, 13px labels, 12px captions, 13px mono code, all lowercase labels)
   - 8px grid spacing system (sp-1 through sp-6)
   - Border radius system (8/16/24/pill/72px)
   - Minimal shadows and borders
   - Header bar structure (4 control groups: design selector, mode selector, more button, preview selector)
   - Mode selector toggle (chat/settings, mutually exclusive, active=filled)
   - Preview selector toggle (phone/desktop/code, mutually exclusive)
   - Four layout patterns (L1=three columns+bottom bar, L2=two columns, L3=stacked, L4=three columns)
   - Drag-handle dividers (1px line, bar indicator, col-resize/row-resize cursor, panel resize)
   - Module panel pattern (white, 24px radius, 16px padding, label above content)
   - Interactive states (hover, active, disabled, focus)
   - Animation defaults (150ms panels, 100ms chips, 200ms modals, instant navigation)
   - Panel-internal scrolling only (no page scroll)
   - Z-index layers (0=base, 100=dropdown, 200-201=modal, 300=toast)

### Files NOT changed (9)

- `02-health-check.feature` -- Infrastructure only, no design impact.
- `09-custom-components.feature` -- API-only spec, no UI in designs.
- `10-visual-diff.feature` -- Backend comparison, no design impact.
- `13-component-rendering-validation.feature` -- Validation spec, no design impact.
- `14-ai-task-pipeline.feature` -- Backend pipeline, no design impact.
- `15-component-svg-assets.feature` -- Asset serving, no design impact.
- `16-figma-json-inspection.feature` -- Debug endpoint, no design impact.
- `17-image-search.feature` -- Search endpoint, no design impact.

### Suggested next steps

- **Developer**: Review updated specs before starting implementation, especially the chat alignment fix and the new Layout/UI spec (18).
- **QA**: Updated specs provide much more testable UI criteria. Generate or update test cases from the new scenarios.
- **Designer**: No action needed -- specs now align with your design descriptions.

---
