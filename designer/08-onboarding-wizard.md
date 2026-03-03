# Onboarding Wizard

> No direct Figma mockup exists for this screen. The design reuses patterns from the home page (`figma/new design.png`) and design system modal (`figma/new design/new design-system.png`). The specification comes entirely from `11-onboarding-wizard.feature`.

---

## Purpose

The onboarding wizard guides new users through a 4-step process to set up their first project. It is accessed at `/onboarding` and walks the user through:

1. **Prompt** -- describe what they want to create
2. **Libraries** -- select or import component libraries
3. **Components** -- review imported components
4. **Organize** -- set up root components and allowed children relationships

After completing all steps, a project (design system + initial design) is created.

---

## Layout

The wizard uses a full-page layout with a centered card, similar to the design system modal but without the overlay behavior (it is a standalone route, not a modal).

```
+--------------------------------------------------------------+
|                                                              |
|  New Project Setup                                           |
|                                                              |
|  [1 Prompt]---[2 Libraries]---[3 Components]---[4 Organize] |
|                                                              |
|  +--------------------------------------------------------+  |
|  |                                                        |  |
|  |              (step content area)                       |  |
|  |                                                        |  |
|  |                                                        |  |
|  |                                                        |  |
|  |                                                        |  |
|  +--------------------------------------------------------+  |
|                                                              |
|                          [Back]           [Next]              |
|                                                              |
+--------------------------------------------------------------+
```

### Specifications

- **Background**: `--bg-page` (warm gray)
- **Container**: Centered card or content area
  - Max-width: ~900px
  - Padding: `--sp-5` (32px)

### Header

- **Title**: "New Project Setup" -- `--text-primary`, 20px, bold
- **Position**: Top of the content area, left-aligned

### Stepper

- **Position**: Below the title, spanning the full width
- **Steps**: Four labeled steps connected by a horizontal line
- **Step indicators**:
  - Each step is a numbered circle + label text
  - **Completed step**: Filled circle (black or dark), label in `--text-primary`
  - **Active step**: Filled circle with ring/outline emphasis, label in `--text-primary`, bold
  - **Upcoming step**: Empty circle (outline only), label in `--text-secondary`
  - **Connecting line**: Thin horizontal line between circles
    - Solid for completed connections
    - Dashed or lighter for upcoming connections

### Step content area

- **Position**: Below the stepper
- **Background**: `--bg-panel` (white)
- **Border-radius**: `--radius-lg` (24px)
- **Padding**: `--sp-4` (24px)
- **Height**: Flexible, fills available space

### Navigation buttons

- **Position**: Below the step content area, right-aligned
- **"Back" button**:
  - Style: Ghost/outline button -- transparent background, `--text-primary` text
  - Border-radius: `--radius-pill`
  - Hidden on Step 1 (no previous step)
- **"Next" button** (or "Create Project" on final step):
  - Style: Same as "generate" button -- `--accent-primary` background, `--text-on-dark` text
  - Border-radius: `--radius-pill`
  - Disabled when step validation fails (gray, no pointer cursor)

---

## Step 1: Prompt

### Content

```
+--------------------------------------------------------+
|                                                        |
| Describe what you want to create                       |
|                                                        |
| +----------------------------------------------------+ |
| |                                                    | |
| |  (large textarea)                                  | |
| |                                                    | |
| |  placeholder: "e.g., A travel booking app with     | |
| |  search, listings, and booking flow"               | |
| |                                                    | |
| +----------------------------------------------------+ |
|                                                        |
+--------------------------------------------------------+
```

- **Instruction text**: "Describe what you want to create" -- 14px, `--text-primary`
- **Textarea**: Large, multi-line text input
  - Same style as the home page prompt panel
  - Placeholder text in `--text-secondary`
  - Full width, ~200px minimum height
- **Validation**: "Next" button is disabled when textarea is empty

---

## Step 2: Libraries

### Content

```
+--------------------------------------------------------+
|                                                        |
| Select component libraries for your project            |
|                                                        |
| +--------------------------------------------------+   |
| | [*] common/depot          ready    12 components |   |
| |                                                  |   |
| | [ ] releu/icons           ready     8 components |   |
| |                                                  |   |
| | [ ] andreas/cubes         importing...           |   |
| +--------------------------------------------------+   |
|                                                        |
| Import from Figma:                                     |
| [ Figma URL input                        ] [Import]    |
|                                                        |
+--------------------------------------------------------+
```

- **Instruction text**: "Select component libraries for your project" -- 14px, `--text-primary`
- **Library list**: Card-based list of available libraries
  - Each row shows:
    - **Checkbox/selection indicator**: Filled when selected, empty when not
    - **Library name**: `--text-primary`, 14px
    - **Status badge**: "ready", "importing", etc. -- pill-shaped, small
    - **Component count**: `--text-secondary`, 13px
  - **Selected state**: Row has `--bg-chip-active` background highlight
  - Clicking a row toggles its selection
- **Import input**: At the bottom of the list area
  - Text input for Figma URL
  - "Import" button next to it (pill-shaped, `--accent-primary`)
  - While importing: progress indicator replaces the button
  - On completion: new library appears in the list above
- **Validation**: "Next" button is disabled when no libraries are selected

---

## Step 3: Components

### Content

```
+--------------------------------------------------------+
|                                                        |
| Review imported components                             |
|                                                        |
| +--------------------------------------------------+   |
| | Component Sets (5)                               |   |
| |   Page          Component Set    3 variants      |   |
| |   Card          Component Set    4 variants      |   |
| |   Button        Component Set    6 variants      |   |
| |   Title         Component Set    2 variants      |   |
| |   NavBar        Component Set    2 variants      |   |
| |                                                  |   |
| | Standalone Components (3)                        |   |
| |   Divider       Component                        |   |
| |   Icon          Component        (vector)        |   |
| |   Spacer        Component                        |   |
| +--------------------------------------------------+   |
|                                                        |
+--------------------------------------------------------+
```

- **Instruction text**: "Review imported components" -- 14px, `--text-primary`
- **Section headers**: "Component Sets (N)" and "Standalone Components (N)" -- 14px, bold
- **Component rows**: Each shows:
  - **Name**: `--text-primary`, 14px
  - **Type badge**: "Component Set" or "Component" -- pill-shaped, `--text-secondary`
  - **Extra info**: Variant count, or "(vector)" for SVG components
- **This step is informational** -- no user action required beyond reviewing the list
- **"Next" button is always enabled** on this step

---

## Step 4: Organize

### Content

```
+--------------------------------------------------------+
|                                                        |
| Organize your components                               |
|                                                        |
| Set root components and define which components can    |
| be nested inside others.                               |
|                                                        |
| +--------------------------------------------------+   |
| | Page     [x] Root    Children: [Title] [Card] [+]|   |
| | Card     [ ] Root    Children: --                |   |
| | Button   [ ] Root    Children: --                |   |
| | Title    [ ] Root    Children: --                |   |
| | NavBar   [ ] Root    Children: --                |   |
| +--------------------------------------------------+   |
|                                                        |
| Note: These settings are auto-detected from Figma      |
| conventions (#root suffix, INSTANCE_SWAP properties).  |
| You can adjust them here if needed.                    |
|                                                        |
+--------------------------------------------------------+
```

- **Instruction text**: "Organize your components" -- 14px, `--text-primary`
- **Description**: Brief explanation of what root components and children mean
- **Component rows**: Each component set shows:
  - **Name**: `--text-primary`, 14px
  - **Root toggle**: Checkbox labeled "Root"
    - Checked: This component can be used as the top-level element in AI generation
    - Toggling sends a PATCH request to update `is_root`
  - **Children list**: Pill-shaped tags showing allowed child component names
    - "[+]" button to add more children (opens a dropdown of available components)
    - Tags are removable (click X on the tag)
    - Changes send PATCH requests to update `allowed_children`
- **Note text**: Informational text in `--text-secondary` explaining Figma conventions

---

## Step 4 Completion: "Create Project" Button

On the final step, the "Next" button changes to "Create Project":

- **Label**: "Create Project"
- **Style**: Same as "generate" -- `--accent-primary` background, white text, pill-shaped
- **Behavior**: Creates the design system and initial design, then redirects to home page

---

## States

### Step navigation

| State                | Behavior                                                    |
|----------------------|-------------------------------------------------------------|
| Step 1, empty prompt | "Next" disabled                                             |
| Step 1, text entered | "Next" enabled                                              |
| Step 2, no selection | "Next" disabled                                             |
| Step 2, library selected | "Next" enabled                                          |
| Step 2, importing    | Import progress shown; list updates on completion           |
| Step 3, reviewing    | "Next" always enabled (informational step)                  |
| Step 4, organizing   | "Create Project" always enabled                             |
| Back button          | Returns to previous step; preserves all entered data        |

### Progress preservation

- Navigating back preserves all previously entered data:
  - Step 1 text is retained
  - Step 2 selections are retained
  - Step 4 organize changes are already saved via PATCH requests

---

## Interactions

| Action                              | Result                                                    |
|-------------------------------------|-----------------------------------------------------------|
| Type in prompt (Step 1)             | "Next" becomes enabled                                    |
| Click "Next" (Step 1)              | Advance to Step 2                                         |
| Click library row (Step 2)          | Toggle selection; "Next" enables if any selected          |
| Enter Figma URL + click "Import"    | Library creation + sync; progress shown; list refreshes   |
| Click "Next" (Step 2)              | Advance to Step 3                                         |
| Click "Next" (Step 3)              | Advance to Step 4                                         |
| Toggle "Root" checkbox (Step 4)     | PATCH request to update is_root                           |
| Add/remove children (Step 4)        | PATCH request to update allowed_children                  |
| Click "Create Project" (Step 4)     | Create design system + design; redirect to home           |
| Click "Back" (any step)             | Return to previous step; preserve state                   |

---

## Navigation

| From               | To                                                        |
|--------------------|-----------------------------------------------------------|
| Direct URL         | /onboarding                                               |
| Complete wizard    | Home page (`04-home-new-design.md`) -- with new design system available |
| Browser back       | Standard browser navigation within the wizard steps       |

---

## Spec Coverage

- `11-onboarding-wizard.feature`: All scenarios -- 4-step stepper, prompt entry, library selection, component review, organize, back navigation, completion
