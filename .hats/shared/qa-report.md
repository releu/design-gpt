# QA Report

---

## Workflow Unskip Audit -- 2026-03-04 (51 cascade-skipped tests unskipped)

### What was tested
- Audited all 88 workflow scenarios across 7 feature files
- Identified that 51 tests were cascade-skipped by `@mode:serial` (not explicitly skipped)
- Removed serial mode via post-processing of generated spec files
- No application code was changed

### Results
- INFRASTRUCTURE FIX: `run-tests.sh` now patches generated specs to replace `"mode":"serial"` with `"mode":"default"`
- All 88 workflow scenarios will now run independently. Failures report as failures, not cascade-skips.
- Previous "31 passed, 6 failed, 51 skipped" will become "31+ passed, N failed, 0 skipped"

### How to run
```bash
bash .hats/qa/run-tests.sh workflow
```

### Notes
- Tests run in order within each feature file (import before browse), but failures no longer cascade
- Generation-dependent tests (6 scenarios) require `OPENAI_API_KEY` in `api/.env`
- Import-dependent tests (browsing "QA Cubes/Generate/Improve/etc.") require Figma API access
- The Developer's CSS fixes from dev2qa #7 (border-radius, chat alignment, children-list) must be deployed for those specific tests to pass
- The `playwright.workflow.config.js` now uses a dedicated output directory `.features-gen-workflow/`

---

## Test Suite Inventory -- 2026-03-04 (complete coverage of all 18 manager specs)

### Summary

**134 scenarios across 19 feature files**, organized into 4 test profiles:
- **Fast** (93 tests): API, auth, health, UI layout, onboarding -- no external services required
- **Workflow** (88 tests, requires Figma + OpenAI): DS modal, generation, improvement, export, UI layout -- NO serial cascade skipping
- **Render** (serial, requires Figma): Component-by-component rendering validation
- **All**: Everything combined

Last known fast-suite result: **93/93 passed** (18.3s)

### Coverage Matrix

All 18 manager feature specs are fully covered:

| Manager Spec | QA Feature File | Scenarios |
|---|---|---|
| 01-authentication | 02-authentication.feature | 8 |
| 02-health-check | 01-health-check.feature | 2 |
| 03-figma-import | 04-api-figma-import.feature | 6 |
| 04-design-system-management | 11-design-system-modal.feature | 15 |
| 05-design-generation | 12-design-generation-workflow.feature | 18 |
| 06-design-improvement | 13-design-improvement-workflow.feature | 12 |
| 07-design-management | 03-api-design-management.feature + 17-design-export.feature | 6 + 8 |
| 08-component-library-browser | 16-component-browser-ui.feature | 13 |
| 09-custom-components | 05-api-custom-components.feature | 4 |
| 10-visual-diff | 06-api-visual-diff.feature | 3 |
| 11-onboarding-wizard | 18-onboarding-wizard.feature | 15 |
| 12-preview-rendering | 15-preview-rendering.feature | 10 |
| 13-component-rendering-validation | 14-component-rendering-validation.feature | 7 |
| 14-ai-task-pipeline | 09-api-ai-pipeline.feature | 4 |
| 15-component-svg-assets | 07-api-svg-assets.feature | 3 |
| 16-figma-json-inspection | 08-api-figma-json.feature | 3 |
| 17-image-search | 10-api-image-search.feature | 2 |
| 18-ui-layout-and-design-system | 19-ui-layout-design-system.feature | 15 |

### What each test verifies (by feature)

**01-health-check (2 scenarios)**
- API /api/up returns HTTP 200
- Frontend loads through Caddy proxy, Vue app container element visible

**02-authentication (8 scenarios)**
- Unauthenticated user sees sign-in screen: warm gray bg, centered white card with `[class*='sign-in-card']`, "Sign in to continue" label
- Clicking sign-in card triggers Auth0 login: card disappears, `.App` renders
- Authenticated user sees main app: header bar with 4 control groups, prompt panel, DS panel, AI engine bar, preview frame
- Auto-create user on first login: new auth0_id gets HTTP 200 from /api/designs
- API rejects no token: GET /api/designs without auth header returns 401
- API rejects invalid token: expired/garbage JWT returns 401
- Token refresh on expiry: silent refresh, action succeeds
- Auth0 login error: user stays on sign-in screen, error message visible

**03-api-design-management (6 scenarios)**
- Create design via API: POST /api/designs returns id and status
- List designs: GET /api/designs returns array with design objects
- View design detail: GET /api/designs/:id returns iterations and chat messages
- Rename: PATCH /api/designs/:id with name returns updated name
- Delete: DELETE /api/designs/:id returns 204
- Access other user's design: returns 404

**04-api-figma-import (6 scenarios)**
- Create library: POST /api/component-libraries with URL returns id, expects status and figma_file_key
- Duplicate URL: same URL returns existing library
- Trigger sync: POST /api/component-libraries/:id/sync returns pending status
- List libraries: GET /api/component-libraries returns array
- Available libraries: GET /api/component-libraries/available returns own + public
- Library detail: GET /api/component-libraries/:id returns components and status

**05-api-custom-components (4 scenarios)**
- Upload: POST /api/custom-components returns 201 with id and compiled code
- Update: PATCH /api/custom-components/:id updates react_code
- Delete: DELETE /api/custom-components/:id returns 204
- Cannot upload to other user's library: returns 404

**06-api-visual-diff (3 scenarios)**
- Visual diff data: GET /api/components/:id/visual_diff returns match_percent and flags
- Figma screenshot: GET /api/components/:id/screenshots/figma returns image
- Invalid screenshot type: GET /api/components/:id/screenshots/invalid returns 400

**07-api-svg-assets (3 scenarios)**
- Component SVG: GET /api/components/:id/svg returns SVG content
- Component set SVG: GET /api/component-sets/:id/svg returns SVG content
- HTML preview: GET /api/components/:id/html_preview returns standalone HTML page

**08-api-figma-json (3 scenarios)**
- Component JSON: GET /api/components/:id/figma_json returns raw Figma data
- Component set JSON: GET /api/component-sets/:id/figma_json returns default variant data
- No JSON stored: returns null figma_json field

**09-api-ai-pipeline (4 scenarios)**
- Create task: POST /api/designs creates design with AI task, returns id
- Poll tasks: GET /api/tasks/next with TASKS_TOKEN returns pending task
- Complete task: PATCH /api/tasks/:id updates state
- Unauthorized: GET /api/tasks/next without token returns 401

**10-api-image-search (2 scenarios)**
- Search images: GET /api/images?q=query returns JSON results
- Empty query: GET /api/images without q returns graceful response

**11-design-system-modal (15 scenarios)**
- Modal opens as full-screen overlay: `.DesignSystemModal` visible, overlay covers viewport
- Close button top-left: `[class*='modal-close']` or fallback
- Centered modal card: visible with border-radius >= 16px
- Two-pane layout: left sidebar + right content area
- Overview item: "Overview" in menu items
- Import flow: add Figma URL, click import, browser visible within 10 min
- Component browser: menu lists component names under file headers
- Name and save: enter name, click Save, modal closes
- DS appears in selector: `.LibrarySelector__item-name` with saved name
- Browse existing DS: click "edit", browser opens, Overview shows name and files
- Component detail: name, type badge, status badge visible
- Root component: config tag root badge, allowed children list
- AI Schema: click "AI Schema", browser detail visible

**12-design-generation-workflow (18 scenarios)**
- Home page three-column layout: prompt, DS, preview panels visible
- Prompt panel: white card, "prompt" label, textarea with "describe..." placeholder
- DS panel: library list, selected highlight with edit link, "new" button
- AI engine bar: "ChatGPT" label, dark pill generate button
- Generate flow: enter prompt, select DS, click generate, navigate to /designs/:id
- Design page layout: view mode switcher visible
- Empty state: `.MainLayout__preview-empty` visible during generation
- Generation complete: `.Preview__frame` visible, iframe `#root` not empty
- Desktop view: `.MainLayout__preview-panel_desktop` visible
- Mobile view: `.MainLayout__preview-panel_mobile` visible
- Code view: CodeMirror editor visible with JSX content
- Design dropdown: select with >= 2 options, "new" navigates home
- Code editing: capture content, modify, verify functional

**13-design-improvement-workflow (12 scenarios)**
- Chat panel: `.ChatPanel` visible with input and send button
- Send message: type text, click send, input cleared
- Messages: at least 2 messages, both user and designer types
- User messages: LEFT-aligned, no background bubble
- Designer messages: RIGHT-aligned, warm gray bubble
- Gravity anchoring: messages at bottom of panel
- Chat input bar: pill-shaped, text field, black circle send button
- Send disabled when empty: `.ChatPanel__send_disabled` visible
- Ctrl+Enter sends: keyboard shortcut triggers send
- Send disabled during generation: button disabled
- Auto-scroll: panel scrolled to bottom
- Settings panel: click "Settings" tab, panel visible

**14-component-rendering-validation (7 scenarios)**
- Setup: import Cubes library via UI (or reuse existing)
- Default render: every component renders with non-empty #root
- Full prop validation: every VARIANT, BOOLEAN, TEXT prop produces different HTML
- Text prop visibility: text sentinel appears in rendered output
- Variant diff: different variant values produce different HTML

**15-preview-rendering (10 scenarios)**
- Setup: find ready library renderer URL via API
- Renderer loads: HTML contains react, react-dom, babel scripts
- Root div: #root element attached
- Ready message: React and ReactDOM available on window
- PostMessage render: send JSX, #root has content
- Error handling: nonexistent component shows error, renderer recovers
- No auth: renderer loads without authentication
- Design system renderer: loads at /api/design-systems/:id/renderer
- Iteration renderer: loads at /api/iterations/:id/renderer

**16-component-browser-ui (13 scenarios)**
- Setup: import Cubes library, open DS browser
- Component props: variant selects, capture preview, change variant, preview differs
- React code: expand section, CodeMirror shows function/export/return/React
- Libraries page: at least 1 card, name and status visible
- Library detail: navigate to /libraries/:id, library name heading visible
- Component preview page: grid layout with cards

**17-design-export (8 scenarios)**
- Figma JSON export: GET /api/designs/:id/export_figma contains expected field
- React export: content-type application/zip
- Image export: status 200 or 404
- Duplicate: POST /api/designs/:id/duplicate returns 201 with new id
- More button: visible in header
- Export menu: visible with items
- Export menu items: contains "React" and "image" text

**18-onboarding-wizard (15 scenarios)**
- Page layout: warm gray bg, centered container, "New Project Setup" title
- Stepper: 4 steps, first active, numbered circles with labels
- Step content: white card below stepper
- Navigation: "Next" pill-shaped dark button, "Back" hidden on step 1
- Step 1 Prompt: textarea, type prompt, Next becomes enabled, advances to Libraries
- Step 2 Libraries: select first library, highlighted, Next enabled
- Step 3 Components: list of imported components visible
- Step 4: "Create Project" button visible
- Stepper progress: step 1 completed, step 2 active
- Back preserves data: prompt text still present after back navigation

**19-ui-layout-design-system (15 scenarios)**
- Desktop-only: viewport >= 1200px, no page scroll
- Colors: warm gray bg, white panels, near-black text
- Typography: system font stack, lowercase labels
- Border radius: >= 16px on panels
- Header bar: design selector, mode selector (chat/settings), more button, preview selector (phone/desktop/code)
- Mode selector: chat/settings pills, one active
- Preview selector: phone/desktop/code pills
- Layout 1: three columns + bottom bar on home page
- Prompt panel: white card, label, textarea placeholder
- DS panel: library list, new button
- AI engine bar: ChatGPT label, generate button
- Preview frame: visible in right column, "preview" placeholder text
- Phone frame: border with styling

### Known issues requiring Developer attention

| # | Issue | Priority | Observable contract |
|---|-------|----------|---------------------|
| 1 | POST /api/component-libraries response missing `status` and `figma_file_key` | High | Response body should include `"status":"pending"` and `"figma_file_key":"<extracted-key>"` |
| 2 | POST /api/designs response missing `status` field | High | Response body should include `"status":"generating"` |
| 3 | Screenshots controller returns 404 for invalid type instead of 400 | Medium | GET /api/components/:id/screenshots/invalid should return HTTP 400 with `"Unknown screenshot type"` |
| 4 | No ready library in E2E test DB for visual diff and Figma JSON tests | Medium | `rails e2e:setup` should seed a minimal ready ComponentLibrary + Component, or these tests skip gracefully |
| 5 | 25 components render empty #root (SVG/icon/sub-element components) | Medium | `react_code` for these components likely has empty or error-producing JSX -- inspect DB |
| 6 | Onboarding Step 1 disabled/enabled state check may use wrong attribute | Low | Check whether Next button disabled state is `disabled` attribute vs CSS class |

## How to run

```bash
bash /Users/releu/Code/designgpt/.hats/qa/run-tests.sh fast        # 93 tests, ~18s (no Figma/OpenAI)
bash /Users/releu/Code/designgpt/.hats/qa/run-tests.sh workflow    # Serial workflow (requires Figma + OpenAI)
bash /Users/releu/Code/designgpt/.hats/qa/run-tests.sh render      # Component rendering (requires Figma)
bash /Users/releu/Code/designgpt/.hats/qa/run-tests.sh all         # Everything
```

## Notes

- Base URL: https://design-gpt.localtest.me
- Auth: HS256 JWT tokens signed with `e2e-test-secret-key` (E2E_TEST_MODE=true)
- Test user: auth0|alice123 / alice@example.com
- Services required: Rails on 3000, Vite on 5173, Caddy on 443
- Figma import tests require FIGMA_ACCESS_TOKEN in api/.env
- Design generation tests require OPENAI_API_KEY in api/.env
- The fast suite runs without any external service credentials
- Tests create all data through the UI or API (clean DB with user-only seed)
