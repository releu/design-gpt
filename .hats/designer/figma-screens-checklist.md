# Figma Screens Checklist

What screens and components should exist in the Figma file, mapped to design specs.

Figma file: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service

---

## Screens (top-level frames)

| # | Screen name | Spec file | Figma status | Node ID |
|---|------------|-----------|--------------|---------|
| 1 | `authorization` | 03-authentication-screen.md | exists | 1:2 |
| 2 | `new design` | 04-home-new-design.md | exists | 1:965 |
| 3 | `new design / new design-system` | 04 + 06 (modal over home) | exists | 2:689 |
| 4 | `design / phone` | 05-design-page.md (phone view) | exists | 1:966 |
| 5 | `design / desktop` | 05-design-page.md (desktop view) | exists | 1:967 |
| 6 | `design / code` | 05-design-page.md (code view) | exists | 1:968 |
| 7 | `design / settings` | 05-design-page.md (settings view) | exists | 2:475 |
| 8 | `design system / overview` | 06-design-system-modal.md | **missing** | -- |
| 9 | `design system / component` | 06-design-system-modal.md | **missing** | -- |
| 10 | `design system / ai schema` | 08-ai-schema-view.md | **missing** | -- |
| 11 | `design / export menu` | 05-design-page.md (export dropdown) | **missing** | -- |
| 12 | `design / figma export` | 10-figma-export-popup.md | **missing** | -- |
| 13 | `design / visual diff` | 09-visual-diff-overlay.md | **missing** | -- |

### Notes on missing screens

- **#8-10 (design system modal)**: The right-pane content exists as the `module/settings` symbol (node `2:578`) with `view=overview` and `view=component` variants. What's missing is a full-screen frame showing the complete modal (overlay + close button + two-pane layout with left sidebar). The AI Schema view has no Figma representation at all.
- **#11 (export menu)**: The "..." button exists but there's no frame showing the dropdown open with its three items.
- **#12 (figma export popup)**: Small modal with pairing code + copy button. No Figma frame exists.
- **#13 (visual diff)**: Three-panel comparison (Figma / React / Diff) with match badge. No Figma frame exists.

---

## Reusable components (symbols)

| # | Component | Spec file | Figma status | Node ID |
|---|-----------|-----------|--------------|---------|
| 1 | header | 07-shared-components.md #1 | exists | 1:633 |
| 2 | design-selector | 07-shared-components.md #2 | exists | 1:282 |
| 3 | mode-selector | 07-shared-components.md #3 | exists (2 variants) | 2:528 |
| 4 | preview-selector | 07-shared-components.md #4 | exists (3 variants) | 1:916 |
| 5 | more-button | 07-shared-components.md #5 | exists | 2:428 |
| 6 | module (generic panel) | 07-shared-components.md #6 | exists | 1:33 |
| 7 | slot (placeholder) | 07-shared-components.md #7 | exists | 1:82 |
| 8 | preview (phone/desktop) | 07-shared-components.md #8 | exists | 1:56 |
| 9 | module/chat | 07-shared-components.md #9 | exists | 1:971 |
| 10 | module/code | 07-shared-components.md #10 | exists | 2:420 |
| 11 | module/settings | 06-design-system-modal.md | exists (2 views) | 2:578 |
| 12 | module-content/prompt | 04-home-new-design.md | exists | 2:342 |
| 13 | module-content/design-system | 04-home-new-design.md | exists | 2:350 |
| 14 | module-content/ai-engine | 04-home-new-design.md | exists | 2:284 |
| 15 | design-selector dropdown | 07-shared-components.md #2 | **missing** | -- |
| 16 | export dropdown menu | 05-design-page.md | **missing** | -- |
| 17 | chat input bar (send disabled) | 07-shared-components.md #9 | **missing** | -- |
| 18 | visual diff section | 09-visual-diff-overlay.md | **missing** | -- |
| 19 | match badge (green/amber/red) | 09-visual-diff-overlay.md | **missing** | -- |

---

## Reference frame

| # | Frame | Purpose | Node ID |
|---|-------|---------|---------|
| 1 | layout | Shows all 4 layout types side by side | 1:355 |

This frame is useful as a reference but is not a user-facing screen.

---

## Priority

Screens to add first (highest impact for developer clarity):

1. **Design system modal -- full frame** (#8-9): The most complex UI in the app. Showing the complete overlay with left sidebar + right pane would remove ambiguity about layout proportions, close button placement, and sidebar styling.
2. **Export menu open** (#11): Small effort, clarifies dropdown positioning and item styling.
3. **Figma export popup** (#12): Small modal, easy to mock up, currently spec-only.
4. **AI Schema view** (#10): Tree layout is hard to describe in text alone.
5. **Visual diff expanded** (#13): Three-panel layout with badge colors benefits from a visual reference.
