# Global Design System

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=0-1

## Platform Constraints

- **Desktop-only web application**
- Minimum viewport width: **1200px**
- Minimum viewport height: **600px**
- No mobile or tablet breakpoints -- the app does not adapt to smaller screens
- If the browser window is below minimum dimensions, content may overflow; no responsive reflow is implemented

---

## Color Palette

Five colors total. No tokens, no aliases -- use these names directly.

| Name      | Value     | Usage                                                                    |
|-----------|-----------|--------------------------------------------------------------------------|
| black     | `#1B1B1F` | Primary text, dark buttons, active borders, send button fill             |
| darkgray  | `#565553` | Secondary/muted text, placeholders, subtitles                            |
| lightgray | `#A6A5A2` | Disabled states, subtle borders, dividers                                |
| white     | `#FFFFFF` | Panel/card backgrounds, inputs, text on dark buttons                     |
| fill      | `#EDECE8` | Page background, chip active fill, modal overlay, chat bubbles           |

### Observation

The palette is intentionally minimal -- five values only. No brand color. The design is monochrome with warmth coming from the slightly beige page background (fill).

---

## Typography

### Fonts

- **Body font**: `Suisse Int'l` -- used for ALL text (labels, body, captions, headings, everything)
- **Code font**: `Suisse Int'l Mono` -- used for CodeMirror, code views, monospace contexts

### Size

- **Font size**: 14px for ALL text -- no type scale, no variation
- **Line height**: 18px for ALL text -- no variation
- **Weight**: 400 default; use 500 or 600 only where bold is semantically needed (e.g. component names, section titles)

There is no type scale. Labels, captions, headings, body text, placeholders -- all 14px/18px.

### Text behavior

- No uppercase or letter-spacing transforms observed anywhere
- All labels are lowercase (e.g. "new design", "chat", "settings", "phone", "desktop", "code")
- Placeholder text uses darkgray

---

## Spacing and Layout

### Base unit

Spacing appears to follow an **8px grid** system:

| Token    | Value | Usage                                                  |
|----------|-------|--------------------------------------------------------|
| `--sp-1` | 4px   | Tight internal padding (inside chips)                  |
| `--sp-2` | 8px   | Default internal padding, gap between small elements   |
| `--sp-3` | 16px  | Panel padding, gap between components                  |
| `--sp-4` | 24px  | Larger section spacing                                 |
| `--sp-5` | 32px  | Outer margin around the page layout container          |
| `--sp-6` | 48px  | Extra-large spacing (modal content from edges)         |

### Panel gaps

The gap between adjacent panels (e.g., prompt panel and design-system panel) is approximately **16px** (a visible strip of the page background shows through).

---

## Border Radius

| Token                | Value  | Usage                                                       |
|----------------------|--------|-------------------------------------------------------------|
| `--radius-sm`        | 8px    | Small elements: chips, badges                               |
| `--radius-md`        | 16px   | Cards, panels, input fields, buttons, chat bubbles          |
| `--radius-lg`        | 24px   | Large containers, the preview frame (desktop mode), modals  |
| `--radius-pill`      | 9999px | Pill-shaped elements: header chips, selector toggles, the "generate" button |
| `--radius-phone`     | 72px   | The phone-shaped preview frame (simulates device bezel)     |

All corners are generously rounded. The design avoids sharp corners entirely.

---

## Shadows and Elevation

Shadows are extremely subtle or absent:

- **Panels**: No visible box-shadow. Elevation is conveyed purely by the white panel sitting on the fill page background.
- **Modal**: A slight shadow is visible around the design-system modal card, suggesting `box-shadow: 0 4px 24px rgba(0,0,0,0.08)`.
- **Buttons**: No shadow on the "generate" / send button.

---

## Borders

- Most panels have **no visible border** -- they rely on background-color contrast against the fill page background
- The preview frame (phone/desktop) has a **2px solid black** border to simulate a device outline

---

## Iconography

No icon library. Use Apple emoji everywhere:

- **Close button**: ❎
- **More button**: 🔽
- **Sign-in**: Custom illustration -- hand with 8 fingers
- **Sync**: 🔄
- **Error/warning**: ⚠️
- **Success**: ✅
- **Phone**: 📱
- **Desktop**: 🖥️
- **Code**: ✏️

Apple emoji is the only icon set. No SVGs, no icon font, no custom icons.

---

## Interactive States

- **Hover**: `cursor: pointer` where needed (buttons, links, clickable items). No other visual change.
- **Active/Selected**: Fill background for selectable items (menu items, pills, component names). For buttons: `transform: scale(0.96)` on `:active`.
- **Disabled**: Reduced opacity (0.5), no pointer cursor.

---

## Scrolling Behavior

- The page itself does not scroll -- all scrolling happens inside individual panels
- Chat panel: vertical scroll, auto-scroll to bottom on new messages
- Component tree sidebar: vertical scroll if the list overflows
- Code editor: CodeMirror handles its own internal scrolling
- Preview iframe: internal scrolling (the iframe content scrolls, not the frame itself)

---

## Z-Index Layers

| Layer         | z-index | Content                                          |
|---------------|---------|--------------------------------------------------|
| Base          | 0       | Page background, panels                          |
| Dropdown      | 100     | Design selector dropdown, export menu            |
| Modal overlay | 200     | Design-system modal full-screen overlay          |
| Modal content | 201     | Design-system modal card                         |
| Toast         | 300     | Error / success notifications (if any)           |
