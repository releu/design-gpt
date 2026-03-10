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

2. **`10-component-preview-page.md`** -- Backend-rendered HTML page at `/api/figma-files/:id/preview` showing all components in a grid. Each card has name, type badge, live React preview, variant count, and collapsible Figma JSON. Covers `08-component-library-browser.feature` preview page scenario and `16-figma-json-inspection.feature` lazy-load scenario.

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

## 3 2026-03-06T16:00 -- Designer

Re: Design system simplified -- 5 colors, single font, uniform sizing

Replaced the entire color palette and typography system:
- Font: Suisse Int'l (body), Menlo (code)
- All text: 14px/18px, no type scale
- 5 colors only: black (#1B1B1F), darkgray (#565553), lightgray (#A6A5A2), white (#FFFFFF), fill (#EDECE8)

Updated all 13 design files to use the new system.

---

## 4 2026-03-06T17:00 -- Designer

Re: Pruned stale design files, updated composition model to slots

Audited all 13 design files against the current 10 manager feature specs.

### Deleted (3 files -- no matching feature)
- `08-onboarding-wizard.md` -- onboarding feature was removed
- `09-libraries-pages.md` -- standalone /libraries pages not in specs; browsing covered by DS modal + settings panel
- `10-component-preview-page.md` -- backend dev page, not in any feature spec

### Updated (3 files -- slots model)
- `05-design-page.md` -- Configuration section now shows named slots with allowed children
- `06-design-system-modal.md` -- Configuration section updated: slots listed per-name with allowed children (was flat allowed_children list)
- `11-ai-schema-view.md` -- Tree now shows named slots under each root component; example updated

### Removed stale spec reference
- `05-design-page.md` -- removed reference to deleted `12-preview-rendering.feature`

10 design files remain, each mapping to at least one current feature.

---

## 5 2026-03-06T18:00 -- Designer

Re: Replaced local screenshots and ASCII wireframes with Figma frame links

- Removed all `figma/*.png` reference lines and inline `See: figma/*.png` refs from all 10 design files
- Removed all ASCII wireframe code blocks (box-drawing layouts) from all 10 design files
- Added Figma frame link (`> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=0-1`) to the top of each file
- Deleted the entire `.hats/designer/figma/` directory (all local PNG screenshots)
- Kept all text descriptions (column proportions, component lists, styling specs) intact -- those are what AI agents read

~~Node IDs in the Figma links currently point to the file root (`0-1`). When the Figma MCP server is available, these can be updated to point to specific frames per file.~~ Done in message #6.

---

## 6 2026-03-06T19:00 -- Designer

Re: Updated Figma links with specific frame node IDs

Used Figma MCP to fetch the frame/node structure and mapped each frame to its design file:

- `02-layout-structures.md` → `1-355` (layout frame)
- `03-authentication-screen.md` → `1-2` (authorization frame)
- `04-home-new-design.md` → `1-965` (new design frame)
- `05-design-page.md` → 4 frames: `1-966` (phone), `1-967` (desktop), `1-968` (code), `2-475` (settings)
- `06-design-system-modal.md` → `2-578` (module/settings)
- `07-shared-components.md` → 10 symbol node IDs (header, design-selector, mode-selector, preview-selector, more-button, module, slot, preview, module/chat, module/code)
- `08-ai-schema-view.md` → `2-578` (part of design system modal)
- `09-visual-diff-overlay.md` → `2-578` (part of design system modal)
- `01-global-design-system.md` and `10-figma-export-popup.md` → kept at `0-1` (no dedicated frame)

---

## 7 2026-03-07T10:00 -- Designer

Re: Gap analysis pass -- 3 design files updated for full spec coverage

Compared all 10 current feature specs against the 10 existing design files. Found and closed 4 minor coverage gaps:

### Updated Files (3)

1. **`05-design-page.md`** -- Added "Reset / Revert button on iteration messages" section to the Chat Panel. Each AI response message has a reset link that reverts the design to that iteration's code and preview. Covers `05-design-generation.feature` "Reset JSX to a previous ITERATION" scenario.

2. **`06-design-system-modal.md`** -- Three additions:
   - Added **Figma JSON section** to ComponentDetail view: collapsible, fetched on demand, formatted code block, shows all variants for component sets. Covers `08-component-library-browser.feature` Figma JSON scenarios.
   - Added **import errors summary** state: error list at top of overview after failed import, with clickable component names linking to their detail. Covers `03-figma-import.feature` "Import finishes with errors" scenario.
   - Added **re-import action** on "no code" components: link in component detail header to retry import of individual failed components. Covers `03-figma-import.feature` "Individual component errors" scenario.

3. **`09-visual-diff-overlay.md`** -- Updated match badge thresholds to use **95%** as the fidelity cutoff (was 80%). Components below 95% are now highlighted as low fidelity in the component browser list. Covers `09-visual-diff.feature` "Components below 95% are highlighted" scenario.

### Coverage Summary

All 10 feature specs now have complete design coverage:
- `01-authentication` -- `03-authentication-screen.md`
- `02-health-check` -- no UI (infrastructure only)
- `03-figma-import` -- `06-design-system-modal.md`
- `04-design-system-management` -- `06-design-system-modal.md` + `08-ai-schema-view.md`
- `05-design-generation` -- `04-home-new-design.md` + `05-design-page.md`
- `06-design-improvement` -- `05-design-page.md`
- `07-design-management` -- `05-design-page.md` + `10-figma-export-popup.md`
- `08-component-library-browser` -- `06-design-system-modal.md` + `09-visual-diff-overlay.md`
- `09-visual-diff` -- `09-visual-diff-overlay.md`
- `10-complex-figma-compatibility` -- validation/backend, no UI needed

---
