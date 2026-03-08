# Shared Components

> Figma (header): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-633
> Figma (design-selector): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-282
> Figma (mode-selector): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-528
> Figma (preview-selector): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-916
> Figma (more-button): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-428
> Figma (module): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-33
> Figma (slot): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-82
> Figma (preview): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-56
> Figma (module/chat): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-971
> Figma (module/code): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-420

This document describes reusable UI building blocks that appear across multiple screens.

---

## 1. Header Bar

The header is a single horizontal row containing four groups: DesignSelector (left), ModeSelector (center-left), MoreButton (center-right), PreviewSelector (right).

### Specifications

- **Height**: ~48px
- **Background**: transparent (the page background shows through) -- or optionally fill
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

### Appearance

- **Shape**: Pill/rounded rectangle
- **Background**: white or transparent
- **Border-radius**: `--radius-pill`
- **Text**: Current design name (e.g., "new design", "design #12"), black, centered
- **Dropdown indicator**: A small downward caret/chevron to the right of the text (implied by the dropdown behavior)
- **Width**: Auto-fit to text content, minimum ~160px
- **Height**: ~36px

### Dropdown behavior

When clicked, a dropdown appears below:

- **Dropdown card**: White, `--radius-md` border-radius, subtle shadow
- **Items**: black, ~36px row height, full-width hover highlight
- **"(+) new design"**: Always first item; navigates to home page
- **Other designs**: Listed by name, ordered by most recent
- Selecting an item navigates to that design's page (or home for "new design")

---

## 3. Mode Selector

### Appearance

- **Container**: Horizontal row of two pill-shaped toggles
- **Each pill**:
  - Background (active): fill (light gray fill)
  - Background (inactive): transparent
  - Border-radius: `--radius-pill`
  - Text: black
  - Padding: ~8px 16px
  - Height: ~36px
- **Gap between pills**: `--sp-1` (4px)
- **Behavior**: Mutually exclusive toggle -- exactly one is active at a time
- **Default**: "chat" is active

### States

| Pill      | Active                           | Inactive                    |
|-----------|----------------------------------|-----------------------------|
| chat      | fill, bold weight  | transparent, normal weight  |
| settings  | fill, bold weight  | transparent, normal weight  |

---

## 4. Preview Selector

### Appearance

Three pills: "phone", "desktop", "code". One active at a time.

- **Container**: Horizontal row of three pill-shaped toggles
- **Each pill**: Same styling as Mode Selector pills
  - Active: fill
  - Inactive: transparent
  - Border-radius: `--radius-pill`
  - Text: black
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

### Appearance

- **Text**: "..." (three dots / ellipsis), black- **No background, no border** -- just the text characters
- **Clickable area**: ~36px x 36px (larger than visible text for easy clicking)
- **Cursor**: pointer on hover

### Dropdown menu

See `05-design-page.md` for the export menu dropdown specification.

---

## 6. Module Panel

This is the generic container used for "prompt", "design system", "ai engine", and other content panels.

### Specifications

- **Outer container**:
  - Background: white
  - Border-radius: `--radius-lg` (24px)
  - Padding: `--sp-3` (16px)
  - No border, no shadow
- **Label**:
  - Position: Top-left of the panel, outside the content area
  - Text: black, weight 500
  - Margin-bottom: `--sp-2` (8px) before content
- **Content area**:
  - Background: slightly lighter or same as panel (in some cases a nested gray area)
  - Fills remaining space

---

## 7. Slot Placeholder

### Appearance

A simple gray square placeholder used in wireframes to indicate where dynamic content will appear.

- **Background**: fill (light gray)
- **Border-radius**: `--radius-sm` (8px) or none
- **Size**: Varies based on context
- **Purpose**: Represents a content placeholder in design compositions

This is a design-time element. In the actual implementation, slots are filled with real content (iframe, editor, list, etc.).

---

## 8. Preview Frame

### Phone variant

- **Border**: 2px solid black
- **Border-radius**: `--radius-phone` (72px) -- creates the rounded phone-bezel shape
- **Background**: white
- **Content**: Iframe pointed at the renderer URL
- **Aspect ratio**: Approximately 9:16 (portrait mobile), but height adapts to fill available space
- **Center alignment**: The phone frame is horizontally centered in its column and vertically centered

### Desktop variant

- **Border**: 2px solid black
- **Border-radius**: `--radius-lg` (24px)
- **Background**: white
- **Content**: Same iframe, rendered at full width
- **Sizing**: Fills available width and height of the preview area

### Placeholder state

- When no design is rendered yet, the text "preview" appears centered in darkgray

---

## 9. Chat Panel

### Message styling

| Role       | Alignment    | Background                | Text style              |
|------------|-------------|---------------------------|-------------------------|
| User       | Left        | None (transparent)        | black  |
| AI/Designer | Right (bubble) | fill (warm gray) | black |

- **User messages**: Plain text, left-aligned, no bubble
- **AI messages**: Contained in a rounded bubble
  - Background: fill
  - Border-radius: `--radius-md` (16px)
  - Max-width: ~75% of panel width
  - Padding: 8px 16px
- **Vertical gap between messages**: `--sp-2` (8px)
- **Gravity**: Messages anchor to the bottom; empty space fills from the top

### Input bar

- **Container**: Pill-shaped bar, full width of the chat panel
  - Background: fill (light gray)
  - Border-radius: `--radius-pill`
  - Height: ~44px
  - Padding: 6px 6px 6px 16px
- **Text input**: Transparent background, no border, fills available width
  - Font: black
  - Placeholder: empty or "Type a message..."
- **Send button**: Solid circle at the right end
  - Diameter: ~32px
  - Background: black
  - Icon: White arrow/send icon centered
  - Disabled state: lower opacity or hidden when input is empty or design is generating

### Scrolling

- Chat messages area scrolls vertically (overflow-y: auto)
- Auto-scrolls to bottom on new messages
- Input bar stays pinned at the bottom (does not scroll)

---

## 10. Code Editor

### Specifications

- **Library**: CodeMirror 6 (via vue-codemirror)
- **Language mode**: JSX / HTML
- **Font**: code font
- **Background**: white
- **Line numbers**: Visible in the gutter
- **Syntax highlighting**: Standard color scheme for JSX (tag names, attributes, strings, etc.)
- **Editable**: In the design page code view, the editor is read-write; in the component detail React code view, it is read-only
- **Panel styling**: Same white rounded-corner panel as other modules
- **Height**: Fills available vertical space in its column
- **Scrolling**: CodeMirror manages its own vertical and horizontal scrolling
