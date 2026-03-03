# Global Design System

> Reference mockups: all files under `figma/`

## Platform Constraints

- **Desktop-only web application**
- Minimum viewport width: **1200px**
- Minimum viewport height: **600px**
- No mobile or tablet breakpoints -- the app does not adapt to smaller screens
- If the browser window is below minimum dimensions, content may overflow; no responsive reflow is implemented

---

## Color Palette

### Backgrounds

| Token                  | Value (approx.)  | Usage                                                        |
|------------------------|------------------|--------------------------------------------------------------|
| `--bg-page`            | `#EBEBEA` / warm light gray | Page-level background behind all panels          |
| `--bg-panel`           | `#FFFFFF`        | Card / panel surfaces (prompt area, chat, settings, etc.)    |
| `--bg-input`           | `#FFFFFF`        | Text inputs, textareas                                       |
| `--bg-bubble-user`     | `#F0EFED` / light warm gray | Chat bubbles from the AI / "designer" role      |
| `--bg-bubble-ai`       | transparent / none | User messages have no distinct bubble background -- they are left-aligned plain text |
| `--bg-chip-inactive`   | transparent      | Unselected pill / chip in selectors                          |
| `--bg-chip-active`     | `#EBEBEA` / light gray | Selected pill / chip in selectors                     |
| `--bg-modal-overlay`   | `#EBEBEA`        | Full-screen overlay behind the design-system modal           |

### Foreground / Text

| Token                  | Value            | Usage                                                        |
|------------------------|------------------|--------------------------------------------------------------|
| `--text-primary`       | `#1A1A1A` / near-black | All body text, labels, component names                |
| `--text-secondary`     | `#999999` / medium gray | Placeholder text, subtitles, muted labels            |
| `--text-on-dark`       | `#FFFFFF`        | Text on the dark "generate" / "send" button                  |

### Accents

| Token                  | Value            | Usage                                                        |
|------------------------|------------------|--------------------------------------------------------------|
| `--accent-primary`     | `#1A1A1A` / near-black | "generate" button fill, send-circle fill              |
| `--accent-border`      | `#D4D4D4`        | Subtle 1px borders on panels and cards                       |
| `--accent-divider`     | `#E0E0E0`        | Horizontal/vertical drag-handle divider lines                |

### Observation

The palette is intentionally neutral -- warm off-whites and near-blacks only. There is no brand color. The design is monochrome with warmth coming from the slightly beige page background (`#EBEBEA`).

---

## Typography

All text in the mockups uses a single sans-serif typeface. Based on the rendering style, the font appears to be the system default or a clean geometric sans-serif such as **Inter** or **SF Pro**. Developers should use:

```css
font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, sans-serif;
```

### Scale

| Role             | Size (approx.) | Weight   | Usage                                          |
|------------------|----------------|----------|-------------------------------------------------|
| Body / default   | 14px           | 400      | All standard text, list items, chat messages    |
| Label            | 13px           | 500      | Module labels ("prompt", "design system", "ai engine"), section headers |
| Small / caption  | 12px           | 400      | Placeholder text, secondary descriptions        |
| Code             | 13px           | 400 mono | CodeMirror / code view (`font-family: monospace`) |

### Text behavior

- No uppercase or letter-spacing transforms observed anywhere
- All labels are lowercase (e.g. "new design", "chat", "settings", "phone", "desktop", "code")
- Placeholder text uses `--text-secondary` color

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

- **Panels**: No visible box-shadow. Elevation is conveyed purely by the white panel sitting on the gray page background.
- **Modal**: A slight shadow is visible around the design-system modal card, suggesting `box-shadow: 0 4px 24px rgba(0,0,0,0.08)`.
- **Buttons**: No shadow on the "generate" / send button.

---

## Borders

- Most panels have **no visible border** -- they rely on background-color contrast against `--bg-page`
- The preview frame (phone/desktop) has a **2px solid black** border to simulate a device outline
- Drag-handle dividers between resizable columns are thin **1px** lines with small bar indicators

---

## Iconography

Minimal iconography is used:

- **Close button (x)**: Circular, small, top-left of modal overlays
- **Send button**: Solid black circle (~32px diameter) inside the chat input bar; contains a right-arrow or send icon in white
- **More button (...)**: Three horizontal dots, displayed as plain text -- not a styled icon

No icon library is visibly in use. Icons are likely inline SVGs or text characters.

---

## Interactive States (inferred)

Since the mockups are static, interactive states are inferred from standard patterns:

| Element          | Hover                          | Active / Selected                        | Disabled                     |
|------------------|--------------------------------|------------------------------------------|------------------------------|
| Pill / chip      | Slight background darken       | `--bg-chip-active` fill                  | Reduced opacity (0.5)        |
| Button (dark)    | Slight lighten (e.g. `#333`)   | Press: slight scale-down                 | Gray fill, no pointer cursor |
| Text input       | No change                      | Subtle border or outline                 | Grayed out text, no cursor   |
| Component name   | Background highlight           | `--bg-chip-active` highlight             | --                           |
| Link text ("edit", "open", "remove") | Underline on hover | --                               | --                           |

---

## Animation and Transitions

No animations are specified in the static mockups. Recommended defaults:

- Panel transitions: `150ms ease` for opacity and transform
- Chip/toggle selection: `100ms ease` for background-color
- Modal open/close: `200ms ease` for opacity + slight scale
- No page-transition animations (Vue Router navigations are instant)

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
