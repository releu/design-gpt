# Figma Export Popup

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=0-1
>
> The specification comes from `07-design-management.feature`.

---

## Purpose

The Figma export popup appears when the user selects "Figma (alpha)" from the export dropdown menu on the design page. It displays a pairing code that can be used with a Figma plugin to import the generated design back into Figma.

---

## Context

The popup is triggered from the "..." more button's export dropdown on the design page. It appears as a small modal/popover anchored near the dropdown menu.

---

## Layout

### Specifications

- **Container**: Small modal/popover card
  - Background: white
  - Border-radius: `--radius-md` (16px)
  - Shadow: `0 4px 24px rgba(0,0,0,0.08)` (same as modal)
  - Padding: `--sp-4` (24px)
  - Width: ~320px
  - z-index: 200 (modal layer)

### Components

#### Title

- **Text**: "Figma (alpha)" -- black, bold
- **Close button**: Small "x" in the top-right corner
  - Clickable area: ~24px x 24px
  - Color: darkgray

#### Description

- **Text**: "Use this code in the Figma plugin to import your design." -- black
- **Margin-bottom**: `--sp-3` (16px)

#### Pairing Code

- **Container**: Light gray background (fill), `--radius-sm` (8px) border-radius, `--sp-2` (8px) padding
- **Text**: The pairing code string -- code font, black
- **Width**: Full width of the popup content area

#### Copy Button

- **Style**: Pill-shaped button
  - Background: black
  - Text: "Copy" in white
  - Border-radius: `--radius-pill`
  - Padding: ~8px 20px
- **Position**: Left-aligned below the code display

---

## States

| State              | Description                                              |
|--------------------|----------------------------------------------------------|
| Default            | Code displayed, Copy button active                       |
| Copied             | Copy button text changes to "Copied!" briefly (1-2s)    |
| Loading            | If code needs to be fetched: show loading indicator      |

---

## Interactions

| Action              | Result                                                  |
|---------------------|---------------------------------------------------------|
| Click "Copy"        | Pairing code copied to clipboard; button shows "Copied!"|
| Click close (x)     | Popup closes                                            |
| Click outside popup | Popup closes                                            |
| Escape key          | Popup closes                                            |

---

## Overlay

- A subtle semi-transparent overlay (`rgba(0,0,0,0.1)`) may cover the page behind the popup, or the popup may appear without an overlay (just the shadow provides visual separation)
- Clicking outside the popup dismisses it

---

## Spec Coverage

- `07-design-management.feature`: "Figma export from export menu opens popup with pairing code" -- popup with title, pairing code, Copy button
