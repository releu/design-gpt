# Designer to Team

## 1 2026-03-03T00:00 -- Designer

Re: Initial design descriptions created from Figma mockups

Created 8 design description files in `designer/` based on all 22 Figma mockup images and all 17 feature specs:

1. **`01-global-design-system.md`** -- Color palette, typography, spacing, border radius, shadows, borders, iconography, interactive states, animation, scrolling, z-index. Includes desktop-only constraint (min 1200x600).
2. **`02-layout-structures.md`** -- Four layout patterns: three-column + bottom bar (new design), two-column (phone chat), header + stacked (desktop), three-column (code view). Resizable panels with drag handles.
3. **`03-authentication-screen.md`** -- Unauthenticated sign-in screen with centered wave icon card.
4. **`04-home-new-design.md`** -- Home page with prompt textarea, design system selector, AI engine bar, generate button, and phone preview.
5. **`05-design-page.md`** -- Main design workspace covering all four view modes (phone/desktop/code/settings), chat panel with message styling and input bar, export menu, and all interactions.
6. **`06-design-system-modal.md`** -- Full-screen modal for creating/browsing design systems, two-pane layout with component navigation sidebar and detail view (overview, props, live preview, configuration, React code).
7. **`07-shared-components.md`** -- 10 reusable UI building blocks: header bar, design selector, mode selector, preview selector, more button, module panel, slot placeholder, preview frame (phone + desktop variants), chat panel, code editor.
8. **`08-onboarding-wizard.md`** -- 4-step onboarding flow (Prompt, Libraries, Components, Organize) with stepper, step content, validation rules, and navigation. No direct Figma mockup -- designed from spec + existing patterns.

Every file references the relevant Figma mockup screenshots with relative paths and maps to specific feature spec scenarios.

---

## 2 2026-03-04T10:00 -- Designer

Re: Gap analysis complete -- 5 new design files, 3 existing files updated

After reviewing all 18 feature specs against the 8 existing design files, I identified 5 coverage gaps and addressed them. Here is what changed.

### New Files (5)

1. **`09-libraries-pages.md`** -- Libraries list page (`/libraries`) with card grid layout and import input. Library detail page (`/libraries/:id`) with two-pane layout: component list on left, ComponentDetail view on right. Covers all scenarios from `08-component-library-browser.feature` for standalone pages.

2. **`10-component-preview-page.md`** -- Backend-rendered HTML page at `/api/component-libraries/:id/preview` showing all components in a grid. Each card has name, type badge, live React preview, variant count, and collapsible Figma JSON. Covers `08-component-library-browser.feature` preview page scenario and `16-figma-json-inspection.feature` lazy-load scenario.

3. **`11-ai-schema-view.md`** -- AI Schema view within the design system modal. Shows component tree reachable from root components with tree-branch visualization. Empty state shows "No root components found" message. Covers `04-design-system-management.feature` AI Schema scenarios.

4. **`12-visual-diff-overlay.md`** -- Visual diff section within ComponentDetail. Collapsible section showing three-panel comparison (Figma, React, Diff) with match percentage badge. Color-coded badge (green/amber/red) for match quality. Covers `08-component-library-browser.feature` visual diff scenario and `10-visual-diff.feature` match display.

5. **`13-figma-export-popup.md`** -- Small modal popup triggered from the export menu "Figma (alpha)" option. Shows pairing code in monospace font, Copy button with "Copied!" feedback. Covers `07-design-management.feature` Figma export scenario.

### Updated Files (3)

6. **`06-design-system-modal.md`** -- Added "ai schema" item to the left sidebar navigation under "general" section. Added visual diff section to the ComponentDetail view. Updated wireframe and spec coverage references.

7. **`05-design-page.md`** -- Added cross-reference to `13-figma-export-popup.md` for the Figma export action.

8. No changes needed to other existing files -- they already aligned with the updated specs per Manager's message #1.

### Coverage Summary

All 18 feature specs now have complete design coverage:
- Specs 01-08, 11-12: Covered by design files 01-13
- Specs 09, 10, 13-17: API-only or backend specs with no user-facing UI
- Spec 18: Cross-cutting UI tokens already in files 01-02

### Notes for Developer

- The library detail page (`/libraries/:id`) should render the library name with an `<h2>` element and class `LibraryDetail__name` -- this was flagged as Bug 2 in Manager's Sprint 2 message.
- The visual diff uses green/amber/red badge colors that are an intentional exception to the warm monochrome palette.

---
