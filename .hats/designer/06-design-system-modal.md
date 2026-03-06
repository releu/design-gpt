# Design System Modal

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-578

---

## Purpose

This full-screen modal allows users to:
1. Create a new design system by importing Figma component libraries
2. Browse existing design system contents (components, props, previews)
3. Edit design system name, add/remove Figma files, sync with Figma
4. View individual component details with interactive prop editing and live preview

The modal opens from the "new" or "edit" buttons on the home page design system panel.

---

## Layout

### Full-screen overlay

- **Overlay background**: fill (same warm gray as page, or slightly darker with opacity)
- **Close button (x)**: Circular button, top-left corner of the overlay (not the modal card). Approximately 36px diameter, white background, black "x" text. Positioned at roughly 32px from top and left edges.
- **Modal card**: Centered both horizontally and vertically
  - Width: ~65% of viewport (roughly 800-900px on a 1400px screen)
  - Height: ~70% of viewport
  - Background: white
  - Border-radius: `--radius-lg` (24px)
  - Shadow: `0 4px 24px rgba(0,0,0,0.08)`
  - Padding: `--sp-4` (24px)

---

## Modal Content: Two-Pane Layout

### Left pane: Navigation sidebar

- **Width**: ~35% of the modal card width (~250px)
- **Sections**:
  - **"general"**: Section header in darkgray
    - **"overview"**: Clickable item. When active, has fill background with `--radius-sm` rounding
    - **"ai schema"**: Clickable item. Shows the component tree reachable from root components. See `08-ai-schema-view.md` for full specification.
  - **Figma file sections**: Each imported Figma file is a section
    - **File name**: Shown as a section header in darkgray (e.g., "figma file name")
    - **Component names**: Listed below, indented slightly (~16px left padding)
      - Text: black
      - Clickable -- selecting highlights with fill
      - The currently selected component has a distinct background highlight

- **Scrolling**: The left pane scrolls independently if the component list is long

### Right pane: Content area

- **Width**: ~65% of the modal card width
- Content changes based on what is selected in the left pane

---

## Right Pane: Overview View

> Shown when "overview" is selected in the left sidebar

### Components

#### Design system name

- **Label**: "design system" in black, bold
- **Input field**: Text input for the design system name
  - Placeholder: "(input field for name)"
  - Style: Standard text input, full width
  - Editable -- changes are saved on blur or on modal close

#### Figma files list

- **Label**: "figma files" in black
- **Items**: Bulleted list of imported Figma files
  - Each item shows: **file name** (linked text) + "open" link + "remove" link
  - "open": Opens the Figma file in a new browser tab
  - "remove": Removes the file/library from this design system

#### Add Figma file

- **Input**: Text field for entering a new Figma URL
  - Placeholder: "Figma URL"
- **Button**: "add" button next to the input
  - Clicking triggers POST to create a new component library and link it to this design system
  - While importing, a progress indicator should be shown

#### Actions section

- **Label**: "actions:" in black
- **"sync with figma"**: Clickable action text/button
  - Triggers a re-sync of all linked libraries from Figma
  - While syncing, shows progress information

---

## Right Pane: Component Detail View

> Shown when a component is selected in the left sidebar

### Components

#### Component header

- **Component name**: black, bold
- **Figma link**: "link to figma" -- clickable, opens the Figma component in a new tab
- **Sync action**: "sync with figma" -- clickable, triggers re-import of this specific component

#### Type and status badges (from specs)

- **Type badge**: Shows "Component Set" or "Component" -- pill-shaped, small
- **Status badge**: Shows component import status ("ready", "importing", "no code") -- pill-shaped, color-coded

#### Props section

- **Label**: "props" in black
- **Prop list**: Each prop is a bullet item with an interactive control:

| Prop type | Control                                           | Behavior                           |
|-----------|---------------------------------------------------|------------------------------------|
| VARIANT   | Dropdown/select with all variant values           | Selecting a value updates preview  |
| TEXT      | Text input field                                  | Typing updates preview             |
| BOOLEAN   | Checkbox                                          | Toggling updates preview           |

- When any prop value changes, a postMessage is sent to the preview iframe with updated JSX

#### Live preview

- **Label**: "live preview" in black
- **Iframe**: Bordered rectangle (1px solid lightgray)
  - Points to the component library renderer URL
  - Renders the selected component with the current prop values
  - Updates in real-time when props are changed
  - Size: Full width of the right pane, approximately 200-300px height

#### Configuration section (for root components, from specs)

- **Root badge**: Shows "yes" or "no" -- read-only
- **Slots**: Each named slot is listed with its allowed children -- read-only. Example: `content: [Title, Text]`, `actions: [Button, Link]`
- These values are set by Figma conventions (e.g., `#root` suffix, Figma Slots / INSTANCE_SWAP properties) and cannot be edited in the UI

#### Visual diff section

- **Expandable/collapsible section**
- Shows Figma screenshot, React screenshot, and diff image side by side
- Match percentage badge with color coding
- See `09-visual-diff-overlay.md` for full specification

#### React code section (from specs)

- **Expandable/collapsible section**
- Shows the component's generated React source code in a read-only CodeMirror editor
- Code font, syntax highlighting

---

## States

### Creating a new design system

1. Modal opens with empty overview
2. User enters a name
3. User adds a Figma URL and clicks "add"
4. Import progress bar shows during library sync
5. When sync completes, components appear in the left sidebar
6. User can browse components, then close the modal

### Browsing an existing design system

1. Modal opens with the overview pre-filled (name, files)
2. Left sidebar lists all components
3. User clicks components to view details

### Importing (progress)

- While a library sync is in progress:
  - The overview area shows a progress bar or step indicator
  - Progress shows "step N/4" and a message (e.g., "Discovering components...")
  - The left sidebar may show components as they are discovered

### Error state

- If a sync fails, the overview shows an error message
- Individual components that failed code generation show a "no code" status badge

---

## Interactions

| Action                            | Result                                                    |
|-----------------------------------|-----------------------------------------------------------|
| Click "overview" in left sidebar  | Right pane shows the design system overview                |
| Click a component name            | Right pane shows the ComponentDetail view for that component |
| Change a prop value               | Live preview iframe re-renders with updated JSX            |
| Enter name and blur               | Design system name is saved                                |
| Add Figma URL + click "add"       | New library is created and sync begins                     |
| Click "open" on a file            | Opens Figma file in new tab                                |
| Click "remove" on a file          | Removes library from design system (with confirmation)     |
| Click "sync with figma"           | Re-syncs all libraries; progress shown                     |
| Click close button (x)            | Modal closes; underlying page is revealed                  |
| Click overlay background          | Modal closes (same as close button)                        |

---

## Navigation

| From                                  | To                                              |
|---------------------------------------|-------------------------------------------------|
| Home page "new" button                | This modal (create mode)                        |
| Home page "edit" link on library      | This modal (edit mode, pre-populated)           |
| Design page "settings" > component    | Same ComponentDetail view, but inline (not modal) |
| Close modal                           | Return to underlying page                        |

---

## Spec Coverage

- `04-design-system-management.feature`: Create via modal, browse components, component detail, interactive props, AI Schema (see `08-ai-schema-view.md`), configuration read-only
- `03-figma-import.feature`: Create library from URL, sync progress, duplicate URL handling
- `08-component-library-browser.feature`: Component detail with props, preview, React code, configuration
