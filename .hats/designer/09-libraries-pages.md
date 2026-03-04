# Libraries Pages

> No direct Figma mockup exists for these pages. The design reuses patterns from the design system modal (`06-design-system-modal.md`) and shared components (`07-shared-components.md`). The specification comes from `08-component-library-browser.feature`.

---

## Purpose

The libraries pages allow users to:
1. View all their imported component libraries in a list (`/libraries`)
2. View a specific library's components with detail, preview, and code (`/libraries/:id`)

These are standalone pages (not modals), using the same warm gray page background and white panel styling as the rest of the application.

---

## Libraries List Page (`/libraries`)

### Layout

```
+--------------------------------------------------------------+
| [header bar]                                                  |
+--------------------------------------------------------------+
|                                                              |
|  +------------------+  +------------------+  +-------------+ |
|  | UI Kit           |  | Icons            |  |             | |
|  | ready            |  | importing...     |  |   (empty    | |
|  | 12 components    |  | step 2/4         |  |    slot)    | |
|  +------------------+  +------------------+  +-------------+ |
|                                                              |
|  Import from Figma:                                          |
|  [ Figma URL input                           ] [Import]      |
|                                                              |
+--------------------------------------------------------------+
```

### Specifications

- **Background**: `--bg-page` (warm gray)
- **Container**: Centered content area, max-width ~1000px, `--sp-5` (32px) padding
- **Header bar**: Standard header (see `07-shared-components.md`). Design selector shows "new design" or the current context.

### Library Cards

Each library is shown as a card:

- **Background**: `--bg-panel` (white)
- **Border-radius**: `--radius-lg` (24px)
- **Padding**: `--sp-3` (16px)
- **Width**: Cards arranged in a responsive grid (2-3 columns depending on viewport)
- **Height**: Auto, minimum ~120px

Card contents:
- **Library name**: `--text-primary`, 16px, bold
- **Status badge**: Pill-shaped, color-coded
  - "ready" -- `--text-primary` on `--bg-chip-active`
  - "importing" / "converting" / etc. -- `--text-secondary` on lighter background
  - "error" -- red-tinted background
- **Component count**: `--text-secondary`, 13px (e.g., "12 components")
- **Progress bar**: Shown for non-ready libraries, indicating current sync step (e.g., "step 2/4: Importing components...")

### Import Input

- **Position**: Below the library cards grid
- **Label**: "Import from Figma:" -- 14px, `--text-primary`
- **Input**: Text field for Figma URL, standard styling
- **Button**: "Import" -- pill-shaped, `--accent-primary` background, white text
- **While importing**: Progress indicator replaces the button; on completion, the new library card appears in the grid

### Interactions

| Action                     | Result                                                    |
|----------------------------|-----------------------------------------------------------|
| Click a library card       | Navigate to `/libraries/:id`                              |
| Enter Figma URL + Import   | Creates library, triggers sync, card appears in grid      |
| Hover a library card       | Subtle shadow or background change                        |

---

## Library Detail Page (`/libraries/:id`)

### Layout

```
+--------------------------------------------------------------+
| [header bar]                                                  |
+--------------------------------------------------------------+
|                                                              |
|  UI Kit                                                      |
|  ready   |   12 component sets   |   5 standalone components |
|                                                              |
|  +---------------------------+-------------------------------+
|  | Component Sets            | [ComponentDetail view]        |
|  |   Page                    |                               |
|  |   Card                    | component name                |
|  |   Button  <-- selected    | link to figma. sync with figma|
|  |   Title                   |                               |
|  |   NavBar                  | props                         |
|  |                           |   * State [default v]         |
|  | Standalone Components     |   * Label [text input]        |
|  |   Divider                 |                               |
|  |   Icon                    | live preview                  |
|  |   Spacer                  | +---------------------------+ |
|  |                           | |                           | |
|  |                           | +---------------------------+ |
|  |                           |                               |
|  |                           | React code                    |
|  |                           | [collapsible code editor]     |
|  |                           |                               |
|  |                           | Configuration                 |
|  |                           | Root: yes                     |
|  |                           | Children: Title, Card         |
|  +---------------------------+-------------------------------+
|                                                              |
+--------------------------------------------------------------+
```

### Page Header

- **Library name**: `--text-primary`, 20px, bold (e.g., "UI Kit"). Should use an `<h2>` element with a class like `LibraryDetail__name`.
- **Status badge**: Pill-shaped, inline after the name
- **Component counts**: `--text-secondary`, 13px (e.g., "12 component sets | 5 standalone components")

### Two-Pane Layout

The main content area uses a two-pane layout similar to the design system modal:

#### Left pane: Component List (~35% width)

- **Background**: `--bg-panel` (white)
- **Border-radius**: `--radius-lg` (24px)
- **Padding**: `--sp-3` (16px)
- **Sections**:
  - **"Component Sets"** section header -- 14px, bold
  - Component set names listed below, 14px, `--text-primary`
  - **"Standalone Components"** section header -- 14px, bold
  - Standalone component names listed below
- **Selected state**: `--bg-chip-active` background highlight
- **Scrolling**: Independent vertical scroll if list overflows

#### Right pane: Component Detail (~65% width)

Uses the shared **ComponentDetail** view (same as in the design system modal and settings panel). See `06-design-system-modal.md` for the full specification.

The ComponentDetail view includes:
- Component name (16px, bold)
- "link to figma" and "sync with figma" links
- Type badge ("Component Set" or "Component")
- Status badge ("ready", "importing", "no code") with color coding
- Props section with type-dependent controls (VARIANT=dropdown, TEXT=input, BOOLEAN=checkbox)
- Live preview iframe (1px border, full width, ~200-300px height)
- React code section (collapsible, read-only CodeMirror)
- Configuration section (read-only root + children for root components)

### Sync Progress

If the library is not yet "ready":
- A status badge in the page header shows the current status
- A progress bar or step indicator shows the sync progress
- Components may appear incrementally as they are discovered

---

## States

### Libraries List Page

| State                  | Description                                              |
|------------------------|----------------------------------------------------------|
| Default                | Library cards displayed in grid                          |
| No libraries           | Empty state with prominent Import input                  |
| Importing              | Card shows progress bar; import input shows progress     |
| Error on import        | Error message below the import input                     |

### Library Detail Page

| State                  | Description                                              |
|------------------------|----------------------------------------------------------|
| Ready                  | All components listed; detail view functional            |
| Importing              | Status badge shows "importing"; progress visible         |
| Component selected     | Left pane highlights component; right pane shows detail  |
| No selection           | Right pane shows library overview or empty state         |
| Component with no code | Status badge shows "no code" in warning style            |

---

## Navigation

| From                   | To                                                       |
|------------------------|----------------------------------------------------------|
| Any page (header)      | /libraries (via navigation)                              |
| Libraries list         | /libraries/:id (click a card)                            |
| Library detail         | Figma (click "link to figma" in component detail)        |
| Library detail         | Back to /libraries (browser back or breadcrumb)          |

---

## Spec Coverage

- `08-component-library-browser.feature`: Library list, library detail, component detail, props, live preview, React code, configuration, visual diff, sync progress
