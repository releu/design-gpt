# Design Page

> Figma (phone): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-966
> Figma (desktop): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-967
> Figma (code): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=1-968
> Figma (settings): https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-475

---

## Purpose

This is the primary workspace for viewing and improving a generated design. After the user creates a design from the home page, they are redirected here. The page provides:

1. A chat panel for iterative improvement via AI
2. A live preview of the generated design (phone, desktop, or code view)
3. A settings panel to browse the linked component libraries
4. Export functionality via the "..." menu

This screen adapts between **Layout 2, 3, and 4** (from `02-layout-structures.md`) depending on which preview mode is selected.

---

## Header Bar

The header bar on the design page contains:

- **Design selector** (left): Shows the current design name (e.g., "design #12"). Dropdown lists all user designs plus "(+) new design" option.
- **Mode selector** (center-left): Toggles between "chat" (active by default) and "settings"
- **More button** (center-right): "..." opens the export dropdown menu
- **Preview selector** (right): Toggles between "phone" (default), "desktop", and "code"

---

## View: Phone Preview + Chat (Default)

> Uses: **Layout 2** (two columns with header)

### Left column: Chat Panel

See the dedicated "Chat Panel" section below for component details.

### Right column: Preview Frame (Phone)

- **Phone frame**: 2px solid black border, `--radius-phone` (72px) border-radius
- **Content**: Iframe pointed at the renderer URL (`/api/iterations/:id/renderer`)
- **Sizing**: The phone frame is centered in its column, with a fixed aspect ratio that simulates a mobile device (approximately 375 x 667 logical pixels)
- **Vertical centering**: The phone frame floats centered vertically in its column

---

## View: Desktop Preview + Chat

> Uses: **Layout 3** (header + stacked content)

### Top area: Chat Panel (compressed)

- Same chat panel as phone view but displayed at reduced height
- Takes full width of the viewport

### Bottom area: Preview Frame (Desktop)

- **Desktop frame**: 2px solid black border, `--radius-lg` (24px) border-radius
- **Content**: Same iframe, but rendered at a wider viewport
- **Sizing**: Takes full available width, respecting panel padding

---

## View: Code + Chat + Preview

> Uses: **Layout 4** (three columns)

### Left column: Chat Panel (narrow)

- Same chat component, compressed to ~25% width
- Message bubbles wrap earlier due to narrow width

### Center column: Code Editor

- **Content**: CodeMirror editor displaying the current iteration's JSX code
- **Syntax highlighting**: JSX/HTML mode with color highlighting
- **Editable**: The code is live-editable; changes trigger real-time preview updates
- **Font**: code font
- **Background**: White panel, same as other panels
- **Auto-save**: Changes are saved automatically to the current iteration (no save button)

### Right column: Preview Frame (Phone)

- Same phone-frame preview as in the phone view
- Updates in real-time as code is edited

---

## View: Settings Panel

> Replaces the chat panel when "settings" is selected in the mode selector

### Left sidebar (within the settings panel)

- **"general" section**: Contains "overview" as a clickable item
- **File sections**: Each Figma file name is shown as a gray section header, with component names listed below
- **Component names**: Clickable list items; the selected one gets fill highlight
- **Scrollable**: If the list overflows, it scrolls independently

### Right content area (within the settings panel)

Depends on what is selected in the left sidebar:

**Overview selected**: Shows design system overview (name, linked files)

**Component selected**: Shows ComponentDetail view with:
- **Component name**: Bold, top of the panel
- **Figma link**: "link to figma. sync with figma" -- a link to the Figma source + a sync action
- **Props section**: Lists each React prop with input controls:
  - VARIANT props: dropdown/select
  - TEXT props: text input
  - BOOLEAN props: checkbox
- **Live preview**: An iframe rendering the component with the currently configured props
- **Configuration** (for root components): Shows "Root: yes" badge and named slots with their allowed children

This is the same ComponentDetail view used in the design system modal (see `06-design-system-modal.md`).

---

## Chat Panel (Detailed)

### Message display

- **User messages**: Left-aligned plain text, no background bubble, black
- **AI/Designer messages**: Right-aligned, displayed in a rounded bubble
  - Background: fill
  - Border-radius: `--radius-md` (16px)
  - Padding: `--sp-2` (8px) vertical, `--sp-3` (16px) horizontal
- Messages are listed chronologically, oldest at top, newest at bottom
- The panel auto-scrolls to the bottom when new messages arrive
- If there are fewer messages than the panel height, messages are gravity-anchored to the bottom (empty space above)

### Message input bar

- **Position**: Pinned to the bottom of the chat panel
- **Appearance**: Rounded pill-shaped container
  - Background: fill
  - Border-radius: `--radius-pill`
  - Height: ~44px
- **Text input**: Takes up most of the bar width; placeholder text is not visible in the mockup (likely empty or "Type a message...")
- **Send button**: A solid black circle (~32px diameter) at the right end of the input bar
  - Contains a white arrow/send icon
  - Disabled (visually grayed or hidden icon) when input is empty
  - Disabled while the design is in "generating" state

### Keyboard shortcut

- **Ctrl+Enter** (or Cmd+Enter on Mac): Sends the message (same as clicking the send button)

---

## Export Menu (More Button)

When the user clicks the "..." button in the header, a dropdown appears with three items: "Download React project", "Download image", "Figma (alpha)".

- **Position**: Dropdown menu anchored below the "..." button
- **Styling**: White card, `--radius-md` border-radius, subtle shadow
- Each item is a clickable row with black text
- Hover state: light gray background on the row

### Actions

| Menu item              | Behavior                                                     |
|------------------------|--------------------------------------------------------------|
| Download React project | GET /api/designs/:id/export_react -- triggers zip download   |
| Download image         | GET /api/designs/:id/export_image -- triggers PNG download   |
| Figma (alpha)          | Opens a popup with a pairing code for Figma plugin integration (see `10-figma-export-popup.md`) |

---

## States

### Generating (polling)

- Design status is "generating"
- The preview area may show a loading indicator or the placeholder text
- Chat input send button is disabled
- The frontend polls GET /api/designs/:id every 1 second
- When status changes to "ready", polling stops and the preview renders

### Ready

- Preview iframe shows the generated design
- Chat input is active and ready for improvement messages
- Export menu items are functional

### Error

- If generation fails, the preview area shows an error indication
- Chat panel may show a system message indicating failure
- User can retry by sending a new improvement message

### Empty chat

- When there are no chat messages yet (brand new design), the chat area is empty
- Messages appear gravity-anchored to the bottom as they arrive

---

## Interactions

| Action                              | Result                                                     |
|-------------------------------------|------------------------------------------------------------|
| Type in chat input + send           | POST /api/designs/:id/improve; design goes to "generating" |
| Ctrl+Enter in chat input            | Same as clicking send                                      |
| Empty input + click send            | No action (button disabled)                                |
| Click "phone" in preview selector   | Switch to phone preview layout (Layout 2)                  |
| Click "desktop" in preview selector | Switch to desktop preview layout (Layout 3)                |
| Click "code" in preview selector    | Switch to code editor layout (Layout 4)                    |
| Click "chat" in mode selector       | Show chat panel                                            |
| Click "settings" in mode selector   | Show settings/component browser panel                      |
| Click "..." more button             | Open export dropdown menu                                  |
| Edit code in code view              | Live preview updates; auto-save to iteration               |
| Select design from dropdown         | Navigate to that design's page                             |
| Select "(+) new design"             | Navigate to home/new design page                           |

---

## Navigation

| From                | To                                                     |
|---------------------|--------------------------------------------------------|
| Home page + generate | This page (redirect after POST /api/designs)          |
| Design dropdown     | Other design pages or home page                        |
| "..." > exports     | File downloads (stay on page) or Figma popup           |

---

## Spec Coverage

- `05-design-generation.feature`: View mode switching, design name in dropdown, code view editing, live preview
- `06-design-improvement.feature`: Chat send, history display, auto-scroll, Ctrl+Enter, empty message prevention, disabled-while-generating
- `07-design-management.feature`: Export menu, download React/image, Figma export, rename, duplicate, delete (via API)
