# Visual Diff Overlay

> No direct Figma mockup exists for this view. It appears as a section within the ComponentDetail view. The specification comes from `08-component-library-browser.feature` and `10-visual-diff.feature`.

---

## Purpose

The visual diff overlay compares how a component looks in Figma versus how it renders in React. It shows three panels side by side: the original Figma screenshot, the React-rendered screenshot, and the difference image. A match percentage badge indicates the fidelity of the React code generation.

This view helps users assess the quality of the Figma-to-React conversion pipeline.

---

## Context

The visual diff appears as an expandable section within the ComponentDetail view (used in the design system modal, settings panel, and library detail page). It sits below the live preview and above or near the React code section.

---

## Layout

### Collapsed State

```
+----------------------------------------------+
| ...other ComponentDetail sections...          |
|                                               |
| visual diff                    [87% match]    |
| (click to expand)                             |
|                                               |
+----------------------------------------------+
```

- **Section label**: "visual diff" -- `--text-primary`, 14px
- **Match badge**: Pill-shaped badge showing the percentage
  - High match (80-100%): Badge with green-tinted or neutral styling
  - Medium match (50-79%): Badge with amber/yellow-tinted styling
  - Low match (0-49%): Badge with red-tinted styling
  - No data: Badge shows "no diff" in `--text-secondary`
- **Expand indicator**: Chevron or arrow indicating the section is collapsible

### Expanded State

```
+----------------------------------------------+
| visual diff                    [87% match]    |
|                                               |
| +----------+  +----------+  +----------+      |
| |          |  |          |  |          |      |
| |  Figma   |  |  React   |  |  Diff    |      |
| |          |  |          |  |          |      |
| +----------+  +----------+  +----------+      |
|   Figma          React          Diff          |
|                                               |
+----------------------------------------------+
```

### Specifications

- **Three-panel layout**: Horizontal row of three equally-sized image panels
- **Panel width**: Each panel takes ~33% of the available width (within the right pane of the ComponentDetail)
- **Panel styling**:
  - Border: 1px solid `--accent-border`
  - Border-radius: `--radius-sm` (8px)
  - Background: white
  - Overflow: hidden (images cropped to fit)
- **Panel labels**: Centered below each panel
  - "Figma", "React", "Diff" -- `--text-secondary`, 12px
- **Images**: Loaded from API endpoints:
  - Figma screenshot: `/api/components/:id/screenshots/figma`
  - React screenshot: `/api/components/:id/screenshots/react`
  - Diff image: `/api/components/:id/diff_image`
- **Image sizing**: `object-fit: contain` within the panel, maintaining aspect ratio
- **Panel height**: ~150-200px, or auto based on image aspect ratio

### Match Badge Styling

| Range      | Background              | Text color     |
|------------|-------------------------|----------------|
| 80-100%    | `#E8F5E9` (light green) | `#2E7D32`      |
| 50-79%     | `#FFF8E1` (light amber) | `#F57F17`      |
| 0-49%      | `#FFEBEE` (light red)   | `#C62828`      |
| No data    | `--bg-chip-active`      | `--text-secondary` |

Note: These colors are an exception to the warm monochrome palette, used specifically for status indication in the visual diff context. They follow standard traffic-light conventions for quick scanning.

---

## States

| State                       | Description                                              |
|-----------------------------|----------------------------------------------------------|
| Collapsed (has data)        | Shows "visual diff" label + match percentage badge       |
| Collapsed (no data)         | Shows "visual diff" label + "no diff" badge              |
| Expanded (all images)       | Three panels with Figma, React, and Diff images          |
| Expanded (missing images)   | Panel shows placeholder text for missing image           |
| Loading                     | Images show loading state while fetching                 |

---

## Interactions

| Action                       | Result                                                  |
|------------------------------|---------------------------------------------------------|
| Click section header         | Toggle expand/collapse                                  |
| Click a panel image          | Optionally: open full-size image in new tab             |

---

## Spec Coverage

- `08-component-library-browser.feature`: "Component detail modal shows visual diff" -- three panels (Figma, React, Diff) + match percentage
- `10-visual-diff.feature`: "Match percentage displayed in component detail" -- badge with styling tiers
