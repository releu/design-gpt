# Shared Components

> Reference mockups:
> - `figma/header.png` (header bar)
> - `figma/mode-selector.png` (chat/settings toggle)
> - `figma/preview-selector.png` (phone/desktop/code toggle)
> - `figma/design-selector.png` (design name dropdown)
> - `figma/more-button.png` (export menu trigger)
> - `figma/module.png` (module panel template)
> - `figma/slot.png` (slot placeholder)
> - `figma/preview.png` (preview frame)
> - `figma/module/chat.png` (chat panel)
> - `figma/module/code.png` (code editor -- reused in settings view)

This document describes reusable UI building blocks that appear across multiple screens.

---

## 1. Header Bar

> Mockup: `figma/header.png`

### Layout

```
+--------------------------------------------------------------+
| new design      chat   settings       ...  phone desktop code|
+--------------------------------------------------------------+
```

The header is a single horizontal row containing four groups of controls:

```
[DesignSelector]  [ModeSelector]       [MoreButton]  [PreviewSelector]
     left           center-left         center-right        right
```

### Specifications

- **Height**: ~48px
- **Background**: transparent (the page background shows through) -- or optionally `--bg-page`
- **Padding**: `--sp-3` (16px) horizontal
- **Alignment**: All groups are vertically centered; distributed with space-between on the horizontal axis
- **No border or shadow** on the header bar itself; it blends into the page

### Positioning within groups

- **Left group**: Design selector -- left-aligned
- **Center-left group**: Mode selector -- positioned after the design selector with a gap
- **Center-right group**: More button -- right of center, before the preview selector
- **Right group**: Preview selector -- right-aligned

---

## 2. Design Selector

> Mockup: `figma/design-selector.png`

### Appearance

```
+---------------------+
|    new design   \/   |
+---------------------+
```

- **Shape**: Pill/rounded rectangle
- **Background**: `--bg-panel` (white) or `--bg-chip-inactive` (transparent with subtle border)
- **Border-radius**: `--radius-pill`
- **Text**: Current design name (e.g., "new design", "design #12"), `--text-primary`, 14px, centered
- **Dropdown indicator**: A small downward caret/chevron to the right of the text (implied by the dropdown behavior)
- **Width**: Auto-fit to text content, minimum ~160px
- **Height**: ~36px

### Dropdown behavior

When clicked, a dropdown appears below:

```
+---------------------+
|    new design   \/   |
+---------------------+
| (+) new design       |
| design #12           |
| My Travel App        |
| Dashboard v2         |
+---------------------+
```

- **Dropdown card**: White, `--radius-md` border-radius, subtle shadow
- **Items**: 14px `--text-primary`, ~36px row height, full-width hover highlight
- **"(+) new design"**: Always first item; navigates to home page
- **Other designs**: Listed by name, ordered by most recent
- Selecting an item navigates to that design's page (or home for "new design")

---

## 3. Mode Selector

> Mockup: `figma/mode-selector.png`

### Appearance

```
+-------+   +-----------+          +-------+   +-----------+
| chat  |   | settings  |          | chat  |   | settings  |
+-------+   +-----------+          +-------+   +-----------+
  active      inactive               inactive     active
```

- **Container**: Horizontal row of two pill-shaped toggles
- **Each pill**:
  - Background (active): `--bg-chip-active` (light gray fill)
  - Background (inactive): transparent
  - Border-radius: `--radius-pill`
  - Text: 14px, `--text-primary`
  - Padding: ~8px 16px
  - Height: ~36px
- **Gap between pills**: `--sp-1` (4px)
- **Behavior**: Mutually exclusive toggle -- exactly one is active at a time
- **Default**: "chat" is active

### States

| Pill      | Active                           | Inactive                    |
|-----------|----------------------------------|-----------------------------|
| chat      | `--bg-chip-active`, bold weight  | transparent, normal weight  |
| settings  | `--bg-chip-active`, bold weight  | transparent, normal weight  |

---

## 4. Preview Selector

> Mockup: `figma/preview-selector.png`

### Appearance

```
+---------+   +-----------+   +--------+
|  phone  |   |  desktop  |   |  code  |
+---------+   +-----------+   +--------+
  active        inactive       inactive
```

Three variants shown in the mockup:

```
Row 1:  [phone*]   desktop    code       <-- phone active
Row 2:   phone    [desktop*]  code       <-- desktop active
Row 3:   phone     desktop   [code*]     <-- code active
```

- **Container**: Horizontal row of three pill-shaped toggles
- **Each pill**: Same styling as Mode Selector pills
  - Active: `--bg-chip-active`
  - Inactive: transparent
  - Border-radius: `--radius-pill`
  - Text: 14px, `--text-primary`
- **Gap between pills**: `--sp-1` (4px)
- **Behavior**: Mutually exclusive toggle
- **Default**: "phone" is active

### Effect on layout

| Selection | Layout used   | Preview frame style            |
|-----------|---------------|--------------------------------|
| phone     | Layout 2      | Phone bezel (72px radius)      |
| desktop   | Layout 3      | Desktop card (24px radius)     |
| code      | Layout 4      | Phone bezel + code editor      |

---

## 5. More Button

> Mockup: `figma/more-button.png`

### Appearance

```
...
```

- **Text**: "..." (three dots / ellipsis), `--text-primary`, 14px
- **No background, no border** -- just the text characters
- **Clickable area**: ~36px x 36px (larger than visible text for easy clicking)
- **Cursor**: pointer on hover

### Dropdown menu

See `05-design-page.md` for the export menu dropdown specification.

---

## 6. Module Panel

> Mockup: `figma/module.png`

### Appearance

```
+--------------------------------------+
| label                                |
| +----------------------------------+ |
| |                                  | |
| |       (content area)             | |
| |                                  | |
| |                                  | |
| +----------------------------------+ |
+--------------------------------------+
```

This is the generic container used for "prompt", "design system", "ai engine", and other content panels.

### Specifications

- **Outer container**:
  - Background: `--bg-panel` (white)
  - Border-radius: `--radius-lg` (24px)
  - Padding: `--sp-3` (16px)
  - No border, no shadow
- **Label**:
  - Position: Top-left of the panel, outside the content area
  - Text: `--text-primary`, 13px, weight 500
  - Margin-bottom: `--sp-2` (8px) before content
- **Content area**:
  - Background: slightly lighter or same as panel (in some cases a nested gray area)
  - Fills remaining space

---

## 7. Slot Placeholder

> Mockup: `figma/slot.png`

### Appearance

A simple gray square placeholder used in wireframes to indicate where dynamic content will appear.

- **Background**: `--bg-chip-active` (light gray)
- **Border-radius**: `--radius-sm` (8px) or none
- **Size**: Varies based on context
- **Purpose**: Represents a content placeholder in design compositions

This is a design-time element. In the actual implementation, slots are filled with real content (iframe, editor, list, etc.).

---

## 8. Preview Frame

> Mockup: `figma/preview.png`

### Phone variant

```
+------------------------------------+
|                                    |
|                                    |
|                                    |
|            preview                 |
|                                    |
|                                    |
|                                    |
+------------------------------------+
```

- **Border**: 2px solid black
- **Border-radius**: `--radius-phone` (72px) -- creates the rounded phone-bezel shape
- **Background**: `--bg-panel` (white)
- **Content**: Iframe pointed at the renderer URL
- **Aspect ratio**: Approximately 9:16 (portrait mobile), but height adapts to fill available space
- **Center alignment**: The phone frame is horizontally centered in its column and vertically centered
- **Notch indicator**: A small horizontal line extends from the left edge of the frame to the column divider (visible in `figma/design/phone.png`)

### Desktop variant

- **Border**: 2px solid black
- **Border-radius**: `--radius-lg` (24px)
- **Background**: `--bg-panel` (white)
- **Content**: Same iframe, rendered at full width
- **Sizing**: Fills available width and height of the preview area

### Placeholder state

- When no design is rendered yet, the text "preview" appears centered in `--text-secondary`

---

## 9. Chat Panel

> Mockup: `figma/module/chat.png`

### Layout

```
+--------------------------------------+
|                                      |
|                                      |
|  user message                        |
|         [ai message bubble]          |
|                                      |
|  user message                        |
|         [ai message bubble]          |
|                                      |
|  user message                        |
|                                      |
| [  input text                  (o) ] |
+--------------------------------------+
```

### Message styling

| Role       | Alignment    | Background                | Text style              |
|------------|-------------|---------------------------|-------------------------|
| User       | Left        | None (transparent)        | `--text-primary`, 14px  |
| AI/Designer | Right (bubble) | `--bg-bubble-user` (warm gray) | `--text-primary`, 14px |

- **User messages**: Plain text, left-aligned, no bubble
- **AI messages**: Contained in a rounded bubble
  - Background: `--bg-bubble-user`
  - Border-radius: `--radius-md` (16px)
  - Max-width: ~75% of panel width
  - Padding: 8px 16px
- **Vertical gap between messages**: `--sp-2` (8px)
- **Gravity**: Messages anchor to the bottom; empty space fills from the top

### Input bar

- **Container**: Pill-shaped bar, full width of the chat panel
  - Background: `--bg-chip-active` (light gray)
  - Border-radius: `--radius-pill`
  - Height: ~44px
  - Padding: 6px 6px 6px 16px
- **Text input**: Transparent background, no border, fills available width
  - Font: 14px, `--text-primary`
  - Placeholder: empty or "Type a message..."
- **Send button**: Solid circle at the right end
  - Diameter: ~32px
  - Background: `--accent-primary` (near-black)
  - Icon: White arrow/send icon centered
  - Disabled state: lower opacity or hidden when input is empty or design is generating

### Scrolling

- Chat messages area scrolls vertically (overflow-y: auto)
- Auto-scrolls to bottom on new messages
- Input bar stays pinned at the bottom (does not scroll)

---

## 10. Code Editor

> Mockup: referenced in `figma/design/code.png`

### Specifications

- **Library**: CodeMirror 6 (via vue-codemirror)
- **Language mode**: JSX / HTML
- **Font**: Monospace, 13px
- **Background**: `--bg-panel` (white)
- **Line numbers**: Visible in the gutter
- **Syntax highlighting**: Standard color scheme for JSX (tag names, attributes, strings, etc.)
- **Editable**: In the design page code view, the editor is read-write; in the component detail React code view, it is read-only
- **Panel styling**: Same white rounded-corner panel as other modules
- **Height**: Fills available vertical space in its column
- **Scrolling**: CodeMirror manages its own vertical and horizontal scrolling
