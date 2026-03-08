# Layout Structures

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-355

The application uses four distinct layout patterns depending on context. All layouts share a common structure: a **header bar** pinned to the top, with the remaining vertical space divided into content areas. The outer page background (fill) is always visible in the gaps between panels.

---

## Viewport and Sizing

- Minimum viewport: **1200px wide x 600px tall** (desktop only)
- The entire layout fills the viewport with no outer scrollbar
- All panels use `overflow: hidden` or `overflow: auto` internally
- The page background is always fill

---

## Layout 1: Three Columns + Bottom Bar (New Design)

> Used on: **Home / New Design page**

### Column proportions (approximate)

- Left column (prompt): ~33%
- Center column (design system): ~33%
- Right column (preview): ~33%
- Bottom bar spans the left + center columns only, not the preview

### Panel sizing

- All three top panels have equal minimum heights, filling the available vertical space below the header
- The bottom bar ("ai engine") is a short fixed-height strip (~60px) pinned below the prompt and design-system panels
- The preview column extends from the header to the bottom of the viewport

---

## Layout 2: Two Columns with Header (Design Page -- Phone/Chat)

> Used on: **Design page with chat panel visible + phone preview**

### Column proportions

- Left column (chat/settings): ~60%
- Right column (preview): ~40%
---

## Layout 3: Header + Full-Width Content (Design Page -- Desktop Preview)

> Used on: **Design page with desktop preview selected**

### Layout notes

- Chat panel takes full width but has a reduced height (top portion)
- Preview area takes full width below the chat panel
- The preview frame uses `--radius-lg` (24px) border radius instead of the phone-style 72px

---

## Layout 4: Three Columns (Design Page -- Code View)

> Used on: **Design page with code view selected**

### Column proportions

- Left column (chat): ~25%
- Center column (code): ~42%
- Right column (preview): ~33%
---

## Common Layout Rules

### Header bar

- Always present at the top of every layout
- Fixed height (~48px)
- Contains navigation controls on the left, mode/preview selectors on the right
- See `07-shared-components.md` for full header specification

### Panel gaps

- Panels are separated by **16px** of visible page background

### Panel styling

- All content panels have:
  - Background: white
  - Border-radius: `--radius-lg` (24px)
  - Padding: `--sp-3` (16px) internally
  - No border, no shadow
  - `overflow: hidden` with internal scroll where needed
