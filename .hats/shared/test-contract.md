# Test Contract

## UI Elements (qa attributes)

| qa attribute | element | context |
|---|---|---|
| `app` | container | Root application container |
| `sign-in-card` | container | Sign-in card/overlay for unauthenticated users |
| `prompt` | container | Prompt section wrapper |
| `prompt-field` | input/textarea | Text field for entering design description |
| `generate-btn` | button | "Generate" button to start AI design generation. Use `.isDisabled()` for disabled state -- no separate qa attribute |
| `library-selector` | container | Design system library selector wrapper |
| `library-item` | container | Individual design system item in the selector list |
| `library-item-name` | span/div | Name text of a design system item |
| `library-browse-btn` | button | "Browse" button on a design system item to open the component browser |
| `new-ds-btn` | button | "New design system" button |
| `ds-modal` | dialog/container | Design system modal overlay |
| `ds-browser` | container | Component browser inside the design system modal |
| `ds-browser-detail` | container | Detail panel inside the component browser |
| `ds-menu-item` | list item | Menu item in the design system sidebar (component name, "Overview", "AI Schema") |
| `ds-menu-subtitle` | heading/span | Subtitle/group header in the DS menu (Figma file name) |
| `ds-name-input` | input | Name input field in the DS overview |
| `ds-save-btn` | button | Save button in the DS modal |
| `ds-add-figma-btn` | button | "+ Figma" button to add a Figma file URL |
| `ds-url-text` | span/div | Displays the added Figma URL text |
| `ds-import-btn` | button | "Import" button to start Figma import |
| `ds-box` | container | Status/progress box inside the DS modal |
| `component-name` | heading/span | Component name in the detail view |
| `component-status` | badge/span | Status badge ("ready", "no code") |
| `component-type` | badge/span | Type badge ("Component Set", "Component", "Vector") |
| `component-preview-frame` | iframe | Preview iframe for component rendering |
| `component-section-header` | heading/button | Collapsible section headers ("Preview", "Props", "React Code", "Figma JSON") |
| `component-props` | container | Props section container |
| `component-prop-row` | row/div | Individual prop row containing name, control, and type. Contains `select`, `input[type="checkbox"]`, or `input[type="text"]` for controls |
| `component-prop-name` | span/label | Prop name label inside a prop row |
| `component-code` | container | Code section wrapper (contains `.cm-content` CodeMirror editor inside) |
| `component-root-tag` | badge/tag | "Root" indicator tag on root components |
| `component-children` | list/container | Allowed children list for slots |
| `component-child` | list item | Individual allowed child entry |
| `component-config-row` | row/div | Configuration row in component detail |
| `component-figma-link` | anchor | Link to the component's Figma source |
| `component-sync-btn` | button | Sync/re-import button on component detail |
| `component-visual-diff` | span/badge | Visual diff percentage indicator |
| `component-low-fidelity` | indicator/badge | Low fidelity warning marker (below 95% diff) |
| `chat-panel` | container | Chat panel wrapper |
| `chat-message` | container | Individual chat message |
| `chat-message-user` | container | User-sent chat message |
| `chat-message-ai` | container | AI/designer chat message |
| `chat-input` | input/textarea | Chat input field |
| `chat-send` | button | Send message button. Use `.isDisabled()` for disabled state -- no separate qa attribute |
| `chat-messages` | container | Scrollable chat messages container (for auto-scroll checks) |
| `preview-frame` | iframe | Main design preview iframe |
| `preview-loading` | container | Loading/spinner state in the preview area |
| `preview-empty` | container | Empty state placeholder when no preview exists |
| `preview-switcher` | container | Preview mode switcher bar |
| `switcher-mobile` | button/tab | "Phone" preview mode toggle |
| `switcher-desktop` | button/tab | "Desktop" preview mode toggle |
| `switcher-code` | button/tab | "Code" preview mode toggle |
| `switcher-settings` | button/tab | "Settings" mode toggle |
| `settings-panel` | container | Settings panel (visible when settings mode is active) |
| `preview-panel-mobile` | container | Preview panel in mobile layout |
| `preview-panel-desktop` | container | Preview panel in desktop layout |
| `design-selector` | select | Design history dropdown selector. Contains `option` elements |
| `export-btn` | button | Export/menu button (opens export dropdown) |
| `export-menu` | container | Export dropdown menu |

## Disabled state handling

Do NOT create separate `qa` attributes for disabled states. Instead:
- `[qa="generate-btn"]` -- check with `page.locator('[qa="generate-btn"]').isDisabled()`
- `[qa="chat-send"]` -- check with `page.locator('[qa="chat-send"]').isDisabled()`

## Active state handling

Do NOT check CSS classes for active states. Instead assert the corresponding panel is visible:
- Settings mode active: assert `[qa="settings-panel"]` is visible
- Chat mode active: assert `[qa="chat-panel"]` is visible

## Elements NOT using qa attributes (keep as-is)

- `#app` -- Vue mount point
- `#root` -- inside renderer iframes
- `.cm-editor`, `.cm-content` -- CodeMirror internals (use `[qa="component-code"]` or `[qa="code-editor"]` as wrapper, then find `.cm-content` inside)
- `pre[style*="color: red"]` -- error indicators inside renderer iframes
- `select`, `input[type="checkbox"]`, `input[type="text"]` -- generic HTML inside `[qa="component-prop-row"]`
- `option` -- dropdown options

## API Endpoints

| method | path | request | response |
|---|---|---|---|
| GET | /api/up | -- | `200` |
| GET | /api/designs | -- | `200 [{ id, status, created_at, ... }]` |
| POST | /api/designs | `{ design: { prompt, design_system_id } }` | `201 { id, ... }` |
| GET | /api/designs/:id | -- | `200 { id, status, ... }` |
| POST | /api/designs/:id/improve | `{ design: { prompt } }` | `200` |
| GET | /api/designs/:id/export_image | -- | `200 image/png` |
| GET | /api/designs/:id/export_react | -- | `200 application/zip` |
| GET | /api/design-systems | -- | `200 [{ id, name, component_library_ids, ... }]` |
| POST | /api/design-systems | `{ name }` | `201 { id, name }` |
| DELETE | /api/design-systems/:id | -- | `204` |
| GET | /api/component-libraries/:id/components | -- | `200 { components, component_sets }` |
| POST | /api/component-libraries | `{ url, design_system_id }` | `201 { id }` |
| POST | /api/component-libraries/:id/sync | -- | `200` |
| GET | /api/components/:id/visual_diff | -- | `200 { similarity_percentage }` |
| POST | /api/custom-components | `{ name, react_code, component_library_id, ... }` | `201` |

## Behaviors

### Authentication (01-authentication.feature)
- Unauthenticated user sees sign-in screen: `[qa="sign-in-card"]` visible, `[qa="prompt"]` and `[qa="library-selector"]` hidden
- Clicking the sign-in control initiates login: `[qa="sign-in-card"]` disappears, `[qa="app"]` appears
- Authenticated user sees the workspace: `[qa="prompt"]` and `[qa="library-selector"]` visible
- Unauthenticated requests are rejected: GET /api/designs returns 401
- Invalid or expired credentials are rejected: GET /api/designs with bad token returns 401
- Token refresh on expiry: expired token 401, fresh token 200

### Health Check (02-health-check.feature)
- API health endpoint responds: GET /api/up returns 200
- Frontend loads through the proxy: page loads 200, `#app` is attached

### Figma Import (03-figma-import.feature)
- Create a new DESIGN_SYSTEM from FIGMA_FILEs: click `[qa="new-ds-btn"]`, add URL via `[qa="ds-add-figma-btn"]`, click `[qa="ds-import-btn"]`, wait for `[qa="ds-browser"]`
- Import progress: `[qa="ds-box"]` shows progress
- Import errors: components with errors show "no code" via `[qa="component-status"]`
- Browse components: `[qa="ds-menu-item"]` lists components, `[qa="ds-menu-subtitle"]` groups by file
- Figma conventions (#root, slots, INSTANCE_SWAP, vectors): `[qa="component-root-tag"]`, `[qa="component-children"]`, `[qa="component-child"]`, `[qa="component-type"]` contains "vector"
- Sync: `[qa="component-sync-btn"]` triggers re-import, `[qa="component-name"]` updates
- Add/remove files: `[qa="ds-add-figma-btn"]`, `[qa="ds-import-btn"]`
- Error handling: `[qa="ds-box"]` shows error text, `[qa="component-sync-btn"]` enabled for retry

### Design System (04-design-system.feature)
- Create/edit DS: `[qa="new-ds-btn"]`, `[qa="ds-name-input"]`, `[qa="ds-save-btn"]`
- List DS: `[qa="library-item-name"]` shows all design systems
- Manage Figma files: `[qa="ds-add-figma-btn"]`, `[qa="ds-url-text"]`, `[qa="ds-import-btn"]`

### Design Generation (05-design-generation.feature)
- Home page elements: `[qa="prompt-field"]`, `[qa="library-selector"]`, `[qa="generate-btn"]`, `[qa="new-ds-btn"]`, `[qa="preview-frame"]` or `[qa="preview-empty"]`
- Generate design: fill `[qa="prompt-field"]`, click `[qa="generate-btn"]`, navigate to /designs/:id
- Preview modes: `[qa="preview-switcher"]`, `[qa="switcher-mobile"]`, `[qa="switcher-desktop"]`, `[qa="switcher-code"]`, `[qa="preview-panel-mobile"]`, `[qa="preview-panel-desktop"]`
- Code view: `.cm-editor` and `.cm-content` visible after clicking `[qa="switcher-code"]`
- Design selector: `[qa="design-selector"]` with options
- Generating state: `[qa="chat-send"]` disabled, `[qa="preview-loading"]` or `[qa="preview-empty"]` shown
- Edge cases: `[qa="generate-btn"]` disabled when no DS selected

### Design Improvement (06-design-improvement.feature)
- Chat history: `[qa="chat-message"]`, `[qa="chat-message-user"]`, `[qa="chat-message-ai"]`
- Send improvement: fill `[qa="chat-input"]`, click `[qa="chat-send"]`
- Auto-scroll: `[qa="chat-messages"]` scrolled to bottom
- Keyboard shortcuts: Ctrl/Cmd+Enter on `[qa="chat-input"]` sends message
- Empty message: `[qa="chat-send"]` disabled when `[qa="chat-input"]` is empty
- Multiple improvements: message count in `[qa="chat-message"]` increases
- Settings panel: click `[qa="switcher-settings"]`, assert `[qa="settings-panel"]` visible

### Design Management (07-design-management.feature)
- List designs: GET /api/designs returns ordered list
- View design: `[qa="preview-frame"]` or `[qa="preview-empty"]` and `[qa="chat-panel"]` visible
- Switch designs: `[qa="design-selector"]` with options including "new"
- Export PNG: GET /api/designs/:id/export_image returns image/png
- Export React: GET /api/designs/:id/export_react returns zip
- Export menu: `[qa="export-btn"]` opens `[qa="export-menu"]`
- Access control: GET /api/designs/:id for other user returns 403/404

### Component Browser (08-component-browser.feature)
- Grouped by file: `[qa="ds-menu-subtitle"]` visible
- Figma link: `[qa="component-figma-link"]` visible
- Sync: `[qa="component-sync-btn"]` clickable
- Props display: `[qa="component-prop-row"]`, `[qa="component-prop-name"]` with >= 3 rows
- Slots: `[qa="component-children"]` with `[qa="component-child"]` items
- Variant/boolean/text props: `select`, `input[type="checkbox"]`, `input[type="text"]` inside `[qa="component-prop-row"]`
- React code: `[qa="component-code"]` with `.cm-content` containing React code
- No-code status: `[qa="component-status"]` text "no code"
- AI schema: `[qa="ds-menu-item"]` with "AI Schema", `[qa="ds-browser-detail"]` visible
- Figma JSON: `[qa="component-section-header"]` with "Figma JSON", code block visible

### Visual Diff (09-visual-diff.feature)
- Standalone diff %: `[qa="component-visual-diff"]` shows percentage
- Variant diff %: multiple `[qa="component-visual-diff"]` elements
- Average diff: `[qa="component-visual-diff"]` contains average %
- Low fidelity highlighting: `[qa="component-low-fidelity"]` visible for < 95%, not visible for >= 95%

### Figma Compatibility (10-figma-compatibility.feature)
- All components render: iterate `[qa="ds-menu-item"]`, check `[qa="component-preview-frame"]` `#root` not empty
- All props work: `[qa="component-prop-row"]` controls update `[qa="component-preview-frame"]` `#root`
- Visual diff passes: API GET /api/components/:id/visual_diff returns >= 95%
