# Visual Diff Overlay

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-578
>
> Appears as a section within the ComponentDetail view. The specification comes from `08-component-library-browser.feature` and `10-visual-diff.feature`.

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

- **Section label**: "visual diff" -- black- **Match badge**: Pill-shaped badge showing the percentage
  - High fidelity (95-100%): Badge with green-tinted styling
  - Low fidelity (80-94%): Badge with amber/yellow-tinted styling
  - Very low fidelity (0-79%): Badge with red-tinted styling
  - No data: Badge shows "no diff" in darkgray
- **Expand indicator**: Chevron or arrow indicating the section is collapsible

### Expanded State

### Specifications

- **Three-panel layout**: Horizontal row of three equally-sized image panels
- **Panel width**: Each panel takes ~33% of the available width (within the right pane of the ComponentDetail)
- **Panel styling**:
  - Border: 1px solid lightgray
  - Border-radius: `--radius-sm` (8px)
  - Background: white
  - Overflow: hidden (images cropped to fit)
- **Panel labels**: Centered below each panel
  - "Figma", "React", "Diff" -- darkgray- **Images**: Loaded from API endpoints:
  - Figma screenshot: `/api/components/:id/screenshots/figma`
  - React screenshot: `/api/components/:id/screenshots/react`
  - Diff image: `/api/components/:id/diff_image`
- **Image sizing**: `object-fit: contain` within the panel, maintaining aspect ratio
- **Panel height**: ~150-200px, or auto based on image aspect ratio

### Match Badge Styling

Per the spec (`09-visual-diff.feature`), components below **95%** are highlighted as low fidelity. Components at or above 95% are not highlighted.

| Range      | Background              | Text color     | Meaning        |
|------------|-------------------------|----------------|----------------|
| 95-100%    | `#E8F5E9` (light green) | `#2E7D32`      | High fidelity  |
| 80-94%     | `#FFF8E1` (light amber) | `#F57F17`      | Low fidelity (highlighted in component list) |
| 0-79%      | `#FFEBEE` (light red)   | `#C62828`      | Very low fidelity (highlighted in component list) |
| No data    | fill      | darkgray | No diff available |

In the component browser list, components below 95% show a small colored dot or badge next to their name to draw attention.

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
