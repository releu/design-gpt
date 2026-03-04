# Component Preview Page

> No direct Figma mockup exists for this page. It is a backend-rendered HTML page served at `/api/component-libraries/:id/preview`. The specification comes from `08-component-library-browser.feature`.

---

## Purpose

This is a standalone HTML page (not part of the Vue app) that renders all components from a library in a visual grid. It serves as a quick overview of every component in the library, showing their live React previews, names, and types.

This page is served by the Rails backend at `/api/component-libraries/:id/preview` and does **not** require authentication.

---

## Layout

```
+--------------------------------------------------------------+
|                                                              |
|  Library Name                                                |
|                                                              |
|  +---------------+  +---------------+  +---------------+     |
|  | Page           |  | Card           |  | Button         |  |
|  | Component Set  |  | Component Set  |  | Component Set  |  |
|  | +----------+  |  | +----------+  |  | +----------+  |     |
|  | |          |  |  | |          |  |  | |          |  |     |
|  | | preview  |  |  | | preview  |  |  | | preview  |  |     |
|  | |          |  |  | |          |  |  | |          |  |     |
|  | +----------+  |  | +----------+  |  | +----------+  |     |
|  | 3 variants    |  | 4 variants    |  | 6 variants    |     |
|  +---------------+  +---------------+  +---------------+     |
|                                                              |
|  +---------------+  +---------------+  +---------------+     |
|  | Icon           |  | Divider        |  | Spacer         |  |
|  | Component      |  | Component      |  | Component      |  |
|  | +----------+  |  | +----------+  |  | +----------+  |     |
|  | | SVG icon |  |  | | preview  |  |  | | preview  |  |     |
|  | +----------+  |  | +----------+  |  | +----------+  |     |
|  +---------------+  +---------------+  +---------------+     |
|                                                              |
+--------------------------------------------------------------+
```

### Specifications

- **Background**: `--bg-page` (warm gray) or white -- since this is a standalone HTML page, styling is self-contained
- **Grid**: CSS grid with 2-3 columns, auto-rows, 16px gap
- **Page padding**: 32px

### Component Card

Each component is a card in the grid:

- **Background**: white
- **Border-radius**: 16px
- **Padding**: 16px
- **Contents**:
  - **Component name**: 16px, bold, near-black
  - **Type badge**: "Component Set" or "Component" -- pill-shaped, small, secondary color
  - **Live preview**: An inline React rendering of the component with default props
    - For component sets: renders the default variant
    - For vector/icon components: displays the SVG image instead
    - Border: 1px solid light gray around the preview area
    - Height: ~200px, overflow hidden
  - **Variant count** (for component sets): "N variants" in secondary text, 13px
  - **Figma JSON section**: Collapsible `<details>` element
    - Label: "Figma JSON"
    - When expanded: fetches JSON asynchronously from `/api/components/:id/figma_json` or `/api/component-sets/:id/figma_json`
    - Displays in a formatted `<pre>` code block

---

## States

| State                       | Description                                              |
|-----------------------------|----------------------------------------------------------|
| All components loaded       | Grid of component cards with live React previews         |
| Component without code      | Card shows "Component not found" error in preview area   |
| Vector component            | Card shows SVG image instead of React preview            |
| Figma JSON expanded         | JSON data fetched and displayed in code block            |
| Loading                     | Page shows loading state while scripts initialize        |

---

## Interactions

| Action                         | Result                                                |
|--------------------------------|-------------------------------------------------------|
| Click "Figma JSON" details     | JSON is fetched asynchronously and displayed          |
| Scroll page                    | Standard browser scrolling (this is not an SPA page)  |

---

## Technical Notes

- This page includes React 18, ReactDOM 18, and Babel standalone scripts
- All component `react_code_compiled` is injected into the page
- Each component card uses `ReactDOM.createRoot` to render the component inline
- No authentication is required (public endpoint)
- The page is server-rendered HTML, not part of the Vue frontend

---

## Spec Coverage

- `08-component-library-browser.feature`: "Component preview page renders all components" -- grid layout, names, types, variants, SVG icons
- `16-figma-json-inspection.feature`: "Figma JSON is lazy-loaded in the preview page" -- collapsible details with async fetch
