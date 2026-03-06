# Home / New Design Screen

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-965

---

## Purpose

This is the primary landing screen for authenticated users. It allows users to:
1. Write a text prompt describing the design they want to create
2. Select which design system (component libraries) to use
3. Trigger AI-powered design generation
4. See a live preview placeholder

This screen uses **Layout 1** (three columns + bottom bar) from `02-layout-structures.md`.

---

---

## Components

### 1. Header Bar

See `07-shared-components.md` for full specification.

On this screen the header contains:
- **Design selector** (left): Shows "new design" as the current selection. Dropdown to switch to existing designs.
- **Mode selector** (center-left): "chat" and "settings" pills. On the new-design page, these control what replaces the prompt/design-system area if the user switches context.
- **More button** (center-right): "..." text, opens the export menu. On the new-design page, this may be disabled or hidden since there is no design to export yet.
- **Preview selector** (right): "phone", "desktop", "code" pills. Controls the preview area format.

### 2. Prompt Panel

- **Position**: Left column, top area
- **Label**: "prompt" -- displayed above the content area in black, weight 500
- **Content**: A large multi-line textarea
  - Placeholder text: "describe what you want to create" in darkgray
  - No visible border on the textarea itself -- it fills the white panel
  - Font: black
  - The textarea expands to fill available vertical space
- **Panel styling**: White card, `--radius-lg`, `--sp-3` padding

### 3. Design System Panel

- **Position**: Center column, top area
- **Label**: "design system" -- displayed above the content area
- **Content**: A scrollable list of available design systems / component libraries

#### Library list items

Each item is a row:
- **Name**: Text like "common/depot", "releu/depot", "andreas/cubes" in black
- **Selected indicator**: The first item ("common/depot") has a subtle background highlight and an "edit" link on the right side
- **"edit" link**: Right-aligned text in darkgray. Clicking opens the design system modal (see `06-design-system-modal.md`)

Items are vertically stacked with `--sp-2` (8px) gap between them.

#### "new" button

- **Position**: Bottom-left of the design system panel
- **Style**: Pill-shaped button, fill background, black text
- **Size**: Auto-width, ~32px height
- **Behavior**: Opens the design system modal in "create new" mode

### 4. AI Engine Bar

- **Position**: Bottom bar spanning the left and center columns
- **Label**: "ai engine" -- displayed above the bar content
- **Content**:
  - **Engine name**: "ChatGPT" in black, bold
  - **Subtitle**: "don't share nda for now" in darkgray -- this is a privacy/configuration note
  - **"generate" button**: Right-aligned, pill-shaped
    - Background: black
    - Text: "generate" in white
    - Border-radius: `--radius-pill`
    - Padding: ~12px 24px
    - This is the primary call-to-action on the page

### 5. Preview Frame

- **Position**: Right column, full height from header to bottom
- **Appearance**: Phone-shaped preview container
  - Border: 2px solid black
  - Border-radius: `--radius-phone` (72px) -- simulates a mobile device bezel
  - Background: white
  - Contains the text "preview" centered (placeholder state)
- **Content**: An iframe that will render the generated design. In the "new design" state, it shows a placeholder or is empty.

---

## States

### Default (empty)

- Prompt textarea is empty with placeholder visible
- Design system list shows available libraries (if any)
- Preview shows "preview" placeholder text
- "generate" button is visible

### No design systems available

- Design system panel shows an empty list
- "new" button is prominently visible
- "generate" button should be **disabled** (per spec: "Generate button should be disabled" when user has no design systems)
- A hint text should appear: "Create a design system to get started" or similar

### Ready to generate

- Prompt has text entered
- At least one design system is selected
- "generate" button is enabled (full black)

### Generating

- After clicking "generate":
  - The page navigates to `/designs/:id` (the design page, see `05-design-page.md`)
  - This screen is no longer visible during generation

---

## Interactions

| Action                           | Result                                                        |
|----------------------------------|---------------------------------------------------------------|
| Type in prompt textarea          | Text appears; no character limit visible                      |
| Click a design system name       | Selects that design system (highlight + "edit" link appears)  |
| Click "edit" on a design system  | Opens the design system modal for that library                |
| Click "new" button               | Opens the design system modal in create mode                  |
| Click "generate"                 | POST /api/designs with prompt + design_system_id; navigate to design page |
| Click "generate" (disabled)      | No action                                                     |
| Select "phone/desktop/code"      | Changes the preview frame style (phone bezel vs. flat card vs. code editor) |
| Select a design from dropdown    | Navigates to that design's page                               |

---

## Navigation

| From                        | To                                                     |
|-----------------------------|--------------------------------------------------------|
| Authentication screen       | This screen (after successful login)                   |
| Design page (via dropdown)  | This screen (selecting "new design" from dropdown)     |
| This screen + "generate"    | Design page (`05-design-page.md`)                      |
| This screen + "edit"/"new"  | Design system modal (`06-design-system-modal.md`)      |

---

## Spec Coverage

- `01-authentication.feature`: "Authenticated user sees the main application" -- prompt area and design system selector visible
- `05-design-generation.feature`: "Generate a design from a prompt" -- prompt entry + design system selection + generate button
- `05-design-generation.feature`: "New user with no design systems sees Generate button disabled"
- `07-design-management.feature`: "Design list appears in the home page dropdown"
- `07-design-management.feature`: "Navigate from design page back to new design"
