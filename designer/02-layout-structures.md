# Layout Structures

> Reference mockup: `figma/layout.png`

The application uses four distinct layout patterns depending on context. All layouts share a common structure: a **header bar** pinned to the top, with the remaining vertical space divided into content areas. The outer page background (`--bg-page`, warm gray) is always visible in the gaps between panels.

---

## Viewport and Sizing

- Minimum viewport: **1200px wide x 600px tall** (desktop only)
- The entire layout fills the viewport with no outer scrollbar
- All panels use `overflow: hidden` or `overflow: auto` internally
- The page background is always `--bg-page`

---

## Layout 1: Three Columns + Bottom Bar (New Design)

> Used on: **Home / New Design page**
> See: `figma/new design.png`

```
+--------------------------------------------------------------+
| [header bar]                                                  |
+-------------------+-------------------+-----------------------+
|                   |                   |                       |
|   prompt          |   design system   |      preview          |
|   (textarea)      |   (selector)      |      (phone frame)    |
|                   |                   |                       |
|                   |                   |                       |
+-------------------+-------------------+                       |
| ai engine  |  ChatGPT  |         [generate]                  |
+----------------------------------------------+---------------+
```

### Column proportions (approximate)

- Left column (prompt): ~33%
- Center column (design system): ~33%
- Right column (preview): ~33%
- Bottom bar spans the left + center columns only, not the preview

### Panel sizing

- All three top panels have equal minimum heights, filling the available vertical space below the header
- The bottom bar ("ai engine") is a short fixed-height strip (~60px) pinned below the prompt and design-system panels
- The preview column extends from the header to the bottom of the viewport

### Resize behavior

- Columns are separated by **vertical drag-handle dividers** (visible as thin 1px lines with a small central bar indicator)
- Users can resize the relative widths of the three columns by dragging these dividers
- The bottom bar has a **horizontal drag-handle divider** above it, allowing vertical resize of the prompt/design-system area vs. the bottom bar

---

## Layout 2: Two Columns with Header (Design Page -- Phone/Chat)

> Used on: **Design page with chat panel visible + phone preview**
> See: `figma/design/phone.png`

```
+--------------------------------------------------------------+
| [design name \/]  [chat | settings]   [...] [phone|desk|code]|
+-----------------------------------------+--------------------+
|                                         |                    |
|   chat panel                            |    preview         |
|   (messages + input)                    |    (phone frame)   |
|                                         |                    |
|                                         |                    |
|                                         |                    |
+-----------------------------------------+--------------------+
```

### Column proportions

- Left column (chat/settings): ~60%
- Right column (preview): ~40%
- A vertical drag-handle divider separates the two columns

---

## Layout 3: Header + Full-Width Content (Design Page -- Desktop Preview)

> Used on: **Design page with desktop preview selected**
> See: `figma/design/desktop.png`

```
+--------------------------------------------------------------+
| [design name \/]  [chat | settings]   [...] [phone|desk|code]|
+----------------------------------------------+---------------+
|   chat panel (compressed height)             |               |
|   [messages + input]                         |               |
+----------------------------------------------+               |
|                                                              |
|            preview (desktop / full-width frame)              |
|                                                              |
+--------------------------------------------------------------+
```

### Layout notes

- Chat panel takes full width but has a reduced height (top portion)
- Preview area takes full width below the chat panel
- A horizontal drag-handle divider separates chat from preview, allowing vertical resizing
- The preview frame uses `--radius-lg` (24px) border radius instead of the phone-style 72px

---

## Layout 4: Three Columns (Design Page -- Code View)

> Used on: **Design page with code view selected**
> See: `figma/design/code.png`

```
+--------------------------------------------------------------+
| [design name \/]  [chat | settings]   [...] [phone|desk|code]|
+------------------+--------------------+----------------------+
|                  |                    |                       |
|  chat panel      |  code editor       |    preview            |
|  (messages +     |  (CodeMirror)      |    (phone frame)      |
|   input)         |                    |                       |
|                  |                    |                       |
|                  |                    |                       |
+------------------+--------------------+----------------------+
```

### Column proportions

- Left column (chat): ~25%
- Center column (code): ~42%
- Right column (preview): ~33%
- Two vertical drag-handle dividers separate the three columns

---

## Common Layout Rules

### Header bar

- Always present at the top of every layout
- Fixed height (~48px)
- Contains navigation controls on the left, mode/preview selectors on the right
- See `07-shared-components.md` for full header specification

### Panel gaps

- Panels are separated by **16px** of visible page background
- This gap contains the drag-handle dividers for resizable layouts

### Drag-handle dividers

- Thin 1px line (`--accent-divider`) running the full height or width of the gap
- A small bar indicator (~20px wide, ~4px tall) centered on the line
- Cursor changes to `col-resize` (vertical) or `row-resize` (horizontal) on hover
- Dragging redistributes the percentage widths/heights of adjacent panels

### Panel styling

- All content panels have:
  - Background: `--bg-panel` (white)
  - Border-radius: `--radius-lg` (24px)
  - Padding: `--sp-3` (16px) internally
  - No border, no shadow
  - `overflow: hidden` with internal scroll where needed
