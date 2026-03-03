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
