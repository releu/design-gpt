# Test Figma Files

Figma files used across all tests (unit, integration, E2E). These are real Figma files with real components.

## 1. Example Lib

| | |
|---|---|
| **Figma URL** | `https://www.figma.com/design/75U91YIrYa65xhYcM0olH5/example-lib` |
| **File key** | `75U91YIrYa65xhYcM0olH5` |
| **Purpose** | Main UI component library |

### Component sets

- **Page** — root component with a slot. Allowed children: Text, Title

### Standalone components

- **Text** — text component
- **Title** — title component. Props: size (variant: m, l), marker (boolean), text (string)
- **lib-component-with-instance** — has an INSTANCE_SWAP property referencing components from Example Icons (for testing cross-file instance linking and INSTANCE_SWAP slot detection)
- **lib-component-without-deps** — no external dependencies (for comparison with the above)

## 2. Example Icons

| | |
|---|---|
| **Figma URL** | `https://www.figma.com/design/dlYQK7x0jXbn8HCFFvZ0lw/example-icons` |
| **File key** | `dlYQK7x0jXbn8HCFFvZ0lw` |
| **Purpose** | Vector components, also used as cross-file instance target from Example Lib |

### Standalone components

- **icon-single** — a single vector component

### Component sets

- **icon-set** — two variants: type=vertical and type=horizontal

## 3. Cubes (E2E only)

| | |
|---|---|
| **Figma URL** | `https://www.figma.com/design/BoLWfKXuDvgWi6ucjHWHK7/DesignGPT-Cubes` |
| **File key** | `BoLWfKXuDvgWi6ucjHWHK7` |
| **Purpose** | Full design system used in E2E workflow tests — real Figma import with the complete sync pipeline |

Has a root component with a slot. This file is imported through the UI in E2E tests and runs through the full Figma sync pipeline (no mocks, no bypasses).
