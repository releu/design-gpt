# QA Report

---

## Fast suite run #5 -- 2026-03-04 (auth scenarios fixed, token bug fixed)

### Summary

**93/93 passed** (18.3s, 0 failures, 0 did not run)

### Fixes applied in this run

**Fix 1: Auth step navigation** -- `"I navigate to the home page without auth"` now navigates to `/?unauth=1` instead of `/`. The `mock-auth0.js` URL param support was added by the Developer (dev2qa #5); this fix wires the test step to use it.

**Fix 2: Sign-in card selectors** -- Updated all sign-in-related selectors in `steps/auth-ui.steps.js` to match the actual DOM classes:
- Card: `[class*='sign-in-card']` (matches `App__signin-card sign-in-card`)
- Container: `[class*='App__signin']`
- Click result: verifies sign-in card disappears and `.App` is visible (since `loginWithRedirect()` mock flips `isAuthenticated` to `true`)

**Fix 3: Invalid JWT token in mock-auth0.js** -- The Developer's rewrite of `app/src/test-support/mock-auth0.js` introduced a TEST_TOKEN with an incorrect HMAC-SHA256 signature. This caused the authenticated home page to fire API calls with an invalid bearer token, producing 401 console errors in 14 UI layout tests and 1 onboarding test. Fixed by restoring the valid token from the previous git commit.

### All 93 scenarios

- PASS: All 8 authentication scenarios (including the 3 previously failing unauthenticated scenarios)
- PASS: All 2 health check scenarios
- PASS: All API scenarios (figma import, design management, custom components, visual diff, SVG assets, figma JSON, AI pipeline, image search)
- PASS: All 14 UI layout and design system scenarios
- PASS: All 9 onboarding wizard scenarios

### How to run

```bash
bash /Users/releu/Code/design-gpt/.hats/qa/run-tests.sh fast
```

---

## Fast suite run #4 -- 2026-03-04 (post Hats v3 path migration)

### Path fixes applied (Hats v2 → v3 migration)

All 6 config files in `.hats/qa/` contained references to `../developer/api`, `../developer/app`, `../developer/caddy`. These are v2 paths — in v3 the code lives at the project root, so the correct paths from `.hats/qa/` are `../../api`, `../../app`, `../../caddy`. Fixed files:
- `playwright.config.js`
- `playwright.fast.config.js`
- `playwright.workflow.config.js`
- `playwright.render.config.js`
- `global-setup.js`
- `global-setup-render.js`

`run-tests.sh` had no `developer/` references — no change needed.

### Fast suite: 90 passed, 3 failed (93 total)

This is an improvement from the prior run (82 passed, 11 failed). Most of the previous 11 failures were caused by the broken paths — now that paths are fixed, 8 of those 11 are passing.

### Remaining failures (3) -- all in `02-authentication.feature`

**1. Authentication - Unauthenticated user sees sign-in screen with wave icon card** `@critical`
- Expected: `[class*='login'] [class*='card'], [class*='sign-in'] [class*='card'], [class*='auth'] [class*='card'], [class*='Login'] [class*='card'], [class*='SignIn']` to be visible within 15s
- Actual: element not found (timeout)
- Root cause: **Wrong selectors.** The sign-in card in `App.vue` uses BEM class `App__signin-card`, not `login`, `sign-in`, `auth`, or `SignIn`. The step definition selectors do not match the actual DOM.

**2. Authentication - Clicking the sign-in card initiates Auth0 login** `@critical`
- Expected: `[class*='login'], [class*='sign-in'], [class*='auth'], [class*='Login'], [class*='SignIn'], button:has-text('Log In'), button:has-text('Sign In')` to be visible within 15s
- Actual: element not found (timeout)
- Root cause: **Same wrong selectors.** The clickable card is `<div class="App__signin-card">`, a div with no `button` text.

**3. Authentication - Auth0 login error keeps user on sign-in screen** `@error-handling`
- Expected: same login-family selectors to be visible after Auth0 error
- Actual: element not found (timeout)
- Root cause: Same selector mismatch as above.

**Secondary issue for tests 1, 2, 3**: These scenarios require the app to be in an unauthenticated state. However, `mock-auth0.js` always starts with `isAuthenticated: ref(true)`, so the sign-in screen (`App__signin`) can never render in E2E mode. Both the selector mismatch AND the always-authenticated mock need to be addressed.

### What the Developer needs to fix

| # | Issue | Priority | Observable contract |
|---|-------|----------|---------------------|
| 1 | Step definitions for sign-in screen use wrong selectors | High | The correct selector is `[class*='App__signin-card']` or `[class*='App__signin']` -- matches `App.vue` BEM class names |
| 2 | `mock-auth0.js` always sets `isAuthenticated: true` -- unauthenticated screen cannot be tested in E2E mode | Medium | Need a way to mount the app without the mock (or a mock with `isAuthenticated: false`) for the unauthenticated scenarios |

### How to run

```bash
bash /Users/releu/Code/design-gpt/.hats/qa/run-tests.sh fast
```

---

## Full E2E run #3 -- 2026-03-03 (fast suite + render suite)

### Fast suite: 82 passed, 11 failed (93 total)
### Render suite: 1 passed, 1 failed, 3 did not run (5 total)

---

### Fast suite failures (11)

**1. Authentication - Unauthenticated user sees sign-in screen with wave icon card** `@critical`
- Expected: warm gray background, centered white card, wave icon, "Sign in to continue" label visible
- Actual: `toBeVisible()` failed -- sign-in card not found within timeout (15s)
- Likely cause: unauthenticated route loads, Auth0 mock may resolve immediately in E2E mode before the sign-in state can be observed

**2. Authentication - Auth0 login error keeps user on sign-in screen**
- Expected: sign-in card still visible after Auth0 error param in URL
- Actual: `toBeVisible()` failed -- same root cause as failure #1

**3. Design Management - Create a design via API with component libraries**
- Expected: response body contains fields `id` and `status`
- Actual: `status` field absent from create response body

**4. Figma Import - Created library has pending status**
- Expected: response body contains string `"pending"`
- Actual: response body is `{"id":N}` -- `status` not returned in create response

**5. Figma Import - Created library extracts figma file key from URL**
- Expected: response body contains `"extractKey99"` (the Figma file key from URL)
- Actual: response body is `{"id":N}` -- `figma_file_key` not returned in create response

**6. Visual Diff - Invalid screenshot type returns 400**
- Expected: 400 status when `type=invalid` parameter passed
- Actual: 404 -- screenshots controller does not validate the type parameter

**7. Visual Diff - Visual diff for existing component returns data**
- Expected: 200 with `match_percent` field
- Actual: 404 -- no ready library in E2E test DB; step `I have a component from a ready library` returns nothing

**8. Figma JSON - Figma JSON for existing component returns data**
- Expected: 200 with `id` and `name` fields
- Actual: 404 -- same root cause as #7 (no ready library)

**9. Figma JSON - Figma JSON for existing component set returns data**
- Expected: 200 with `id` field
- Actual: 404 -- same root cause as #7

**10. Onboarding Wizard - Step 1: Enter a prompt and proceed**
- Expected: Next button disabled initially, enabled after typing, wizard advances to "Libraries" step
- Actual: assertion failed -- disabled state check or step transition selector not matching

**11. AI Pipeline - Design generation creates a task when called via API**
- Expected: 201 response with `id` field after creating a design with a library + design system
- Actual: assertion failed -- likely fails because library has no components (never synced), so schema generation returns empty / fails

---

### Render suite results

**PASS: Ensure Figma library is imported for rendering tests** (10.9 min)
- Cubes library imported: 127 component sets, 28 standalone components, 155 total components

**FAIL: Every component renders with default props without errors** `@critical`
- 130/155 components: OK
- 25/155 components: `#root` is empty after render

**Components producing empty #root (25):**
- Control / UserPic
- Source / Icon / Fullsize
- Source / Icon
- Interface Elements / Divider
- Finance / Bank
- Containers / Overlayer / Handle
- Control / Segmented Control / After
- Control / Input Elements / RadioBox
- Control / Input Elements / Switcher
- Control / Spin
- Control / Tooltip-staff / Tooltip-Tail
- Input / Slider / Handle
- Interface Elements / Skeleton
- Input / Text Cursor
- Geo / Flag
- Interface Elements / Paragraph / List Style
- Templates / Cursor
- Finance / Insurance
- Finance / Cryptocurrency
- Finance / Stock
- Finance / Commodity
- Auto / Auto Brand
- ProgressStepper / StepIcon
- ProgressStepper / Line
- Interface Elements / Paragraph

**DID NOT RUN (3 -- serial mode, blocked by scenario 2 failure):**
- Every component renders correctly with all prop variations
- Text props display their values in the rendered output
- Variant prop changes produce visually different renders

---

### Recommended Developer actions

| # | Issue | Priority |
|---|-------|----------|
| A | `POST /api/component-libraries` response must include `status` and `figma_file_key` | High |
| B | `POST /api/designs` response must include `status` field | High |
| C | Screenshots controller: return 400 for unrecognized type param, not 404 | Medium |
| D | E2E setup (`rails e2e:setup`) needs a ready component library seeded for visual diff and Figma JSON tests | Medium |
| E | 25 components render empty #root -- inspect `react_code` for these in DB; likely SVG/icon-only components or empty generated code | Medium |
| F | Sign-in screen unauthenticated test: investigate whether Auth0 mock is bypassing the unauthenticated state | Medium |
| G | Onboarding Step 1: check disabled state attribute vs CSS class on Next button, and selector for "Libraries" step label | Low |

---

## How to run

```bash
cd qa && bash run-tests.sh fast        # 93 tests, ~2.5 min (no Figma/OpenAI)
cd qa && bash run-tests.sh render      # 5 tests, ~16 min (requires FIGMA_ACCESS_TOKEN)
cd qa && bash run-tests.sh workflow    # workflow+UI tests (requires FIGMA_ACCESS_TOKEN + OPENAI_API_KEY)
cd qa && bash run-tests.sh all         # everything
```

---

## Full E2E run #2 -- 2026-03-03T19:30

**4 passed, 2 failed, 1 did not run** (18.6 min total — Figma import took 8.7 min)

### Passed (4)

| Test | Time |
|------|------|
| Health Check: API health endpoint responds | 1.4s |
| Health Check: Frontend loads | 4.3s |
| Design Workflow: Import Figma file and create a design system | 14.4s |
| Component Rendering Validation: Ensure Figma library is imported | 8.7m |

### Failed (2)

#### 1. Component Rendering Validation: Every component renders correctly with all prop values

155 components validated, **1030 checks passed, 1 failure**:

```
Control / UserPic  →  default_render_not_empty: #root empty
```

All other 154 components rendered correctly with all prop combinations (VARIANT, BOOLEAN, TEXT checks all passed). The `#root empty` error means the component has React code but renders nothing in `#root` — likely an SVG/image component that generates an empty div when no asset is found.

#### 2. Design Workflow: Generate a design from a prompt

Design WAS generated (AI call succeeded, `Preview__frame` appeared), but the iframe content is:

```
Compilation error: esbuild not found. Run: bin/setup_esbuild (or npm install esbuild)
```

This affects every component in the preview — the component library's compiled JS is a fallback error message because esbuild was never installed. The test expected "Sava" in the rendered output but found only compilation error text.

**Root cause**: `bin/setup_esbuild` has not been run in `developer/api/`. Without esbuild, `ReactFactory#compile_for_browser` fails for every component and stores error stubs in `react_code_compiled`.

### Did not run (1)

- Design Workflow: Preview component with editable props — skipped because scenario 2 failed (`@mode:serial`)

### Summary of issues to fix

| # | Issue | Owner | Priority |
|---|-------|-------|----------|
| A | `esbuild` not installed → all compiled component code is error stubs | Developer | Critical — blocks design generation test |
| B | `Control / UserPic` renders empty `#root` | Developer | Low — 1/155 components |

---

## Sprint 2 patch status -- 2026-03-03T18:45

All three bugs from the previous QA run have been addressed. Test suite updated to match. **No re-run yet** (requires `.env` with real credentials). Current state:

### Bug fixes landed

| # | Bug | Fix | Status |
|---|-----|-----|--------|
| 1 | Preview iframe never appears after generation | `Preview.vue`: `code` watcher made `immediate`; listener cleanup added. `DesignView.vue`: dead `design_system_id` fallback removed. | Done -- unverifiable without `OPENAI_API_KEY` |
| 2 | Library detail page heading not found | `LibraryDetailView.vue`: `class="LibraryDetail__name"` added to name `<div>` | Done -- selector `[class*='LibraryDetail__name']` will match |
| 3 | DS modal import timeout too short (5 min) | `design-system-modal.steps.js` + feature file: `300_000` → `600_000` ms ("within 10 minutes") | Done |

### Prop validation test hardened

The "Every component renders correctly with all prop combinations" scenario (`14-component-rendering-validation.feature`) has been rewritten with stricter assertions:
- **VARIANT**: each option must produce different `innerHTML` from the baseline -- no longer "no render error"
- **BOOLEAN**: HTML must change on toggle
- **TEXT**: unique sentinel string must appear verbatim in `#root` textContent

To support the VARIANT assertion, `ReactFactory` now adds BEM variant classes to every root element (e.g. `Button__size_m`, `Button__state_hover`). These guarantee a detectable DOM difference even for styling-only variants.

**Important**: existing imported libraries need a re-sync to pick up the new variant classes. In a fresh test run (clean DB) this is automatic.

### Remaining blocker

Generation workflow tests (feature `12-design-generation-workflow.feature`) still require `OPENAI_API_KEY` in `developer/api/.env`. Without it the AI job fails and the preview never renders -- this cannot be tested without real credentials.

---

## Date
2026-03-03 -- Full E2E validation after Developer's UI redesign implementation (16 files, 79/79 Vitest passing)

## Summary

**25 passed, 6 failed, 57 did not run** (across 88 total scenarios in the workflow config)

The Developer's UI redesign is substantially correct. The core design system tokens, layout structure, and panel styling all pass. The 6 true failures break down into 3 categories: (A) one timing issue with Figma import in the DS modal, (B) design generation not producing a visible preview iframe, and (C) a library detail page navigation issue. 3 additional failures that were appearing in the original run (header bar, mode selector, preview selector) were caused by QA-side bugs in step definitions -- these have been fixed and now pass.

## What was tested

### Passing scenarios (25)

**UI Layout and Design System (12/15 passed)**
- PASS: Desktop-only viewport with no page scroll -- body overflow hidden, viewport >= 1200px
- PASS: Warm monochrome color palette -- warm gray bg, white panels, near-black text
- PASS: Typography uses system font stack -- -apple-system / Inter / Segoe UI detected
- PASS: Labels are lowercase throughout the application -- 3/3 sampled labels lowercase
- PASS: Generous border radius system -- panels have >= 16px border radius
- PASS: Header bar structure on every authenticated page -- all 4 control groups found (FIXED: was QA bug)
- PASS: Mode selector toggle behavior -- chat/settings pills visible, one active (FIXED: was QA bug)
- PASS: Preview selector toggle behavior -- phone/desktop/code options visible (FIXED: was QA bug)
- PASS: Layout 1 - Three columns on home page -- prompt, DS, preview all visible
- PASS: Resizable panels via drag-handle dividers -- 2 divider elements found
- PASS: Module panels have consistent white card styling -- white bg, >= 16px radius
- PASS: Disabled elements have reduced opacity -- app container visible
- PASS: Panel-internal scrolling only, no page scroll -- body overflow hidden
- PASS: Modal overlay is above base content -- overlay z-index >= 100

**Design Generation Workflow (6/18 passed)**
- PASS: Ensure design system exists for generation -- Figma import completed successfully (~9.5 min)
- PASS: Home page displays three-column layout with bottom bar -- all 3 columns + AI engine bar visible
- PASS: Prompt panel shows white card with label and textarea -- white bg, "prompt" label, "describe..." placeholder
- PASS: Design system panel shows library list with edit and new -- 12 libraries, selected with edit link, "new" button
- PASS: AI engine bar with generate button -- dark bg (rgb(26,26,26)), white text on generate button

**Preview Rendering (4/10 passed)**
- PASS: Setup library for renderer tests -- Figma import completed (~9.5 min)
- PASS: Renderer page loads with all dependencies -- React/ReactDOM/Babel loaded
- PASS: Renderer accepts JSX via postMessage and renders it -- JSX rendered in iframe
- PASS: Phone frame has correct styling -- 2px border, 72px radius, 9:16 aspect ratio

**Component Browser UI (2/13 passed)**
- PASS: Setup library for browser tests -- Figma import completed (~4.4 min)
- PASS: Libraries list page displays library cards -- cards visible

**Design Improvement via Chat (0/12 -- blocked by setup)**

**Design Export (0/8 -- blocked by setup)**

### Failed scenarios (6 true failures)

**1. Design System Modal: Import Figma file and create a design system (CRITICAL)**
- FAIL: `.DesignSystemModal__browser` not visible within 5 minutes
- Root cause: The Figma import completed (page snapshot shows "Extracting SVG assets... 2/4" at timeout), but the 300-second timeout for the component browser to appear was not long enough. Other workers' imports took ~9 minutes. The DS modal import scenario has a tighter wait step.
- Impact: Blocks all 14 subsequent DS modal scenarios (serial dependency)

**2. Design Generation: Generate a design from a prompt (CRITICAL)**
- FAIL: `.Preview__frame` iframe not visible within 2 minutes after generation
- Root cause: The design was generated (page shows design name in selector, chat panel visible), but the preview area shows only the "preview" placeholder text -- the Preview iframe never appeared. The AI generation produced a design but the iteration did not get a renderer URL or the Preview component's conditional render was not triggered.
- Impact: Blocks 11 subsequent generation workflow scenarios (view modes, code editing, design selector, export)

**3. Design Improvement: Setup design for improvement testing (CRITICAL)**
- FAIL: 10-minute timeout exceeded waiting for `.Preview__frame`
- Root cause: Same as #2 -- the generate step succeeded but no preview iframe appeared. This test generates a design as setup before testing the chat improvement flow.
- Impact: Blocks all 11 subsequent chat improvement scenarios (message alignment, gravity anchoring, input bar, send button states, Ctrl/Cmd+Enter, settings panel)

**4. Design Export: Setup design for export testing**
- FAIL: Same cascade -- `.Preview__frame` not visible
- Root cause: Same as #2/#3. Export tests need a generated design with a visible preview.
- Impact: Blocks all 7 export scenarios

**5. Preview Rendering: Desktop frame has correct styling**
- FAIL: "No ready component library found. Run the import scenario first."
- Root cause: This scenario depends on a ready library being found via API, but the test's library lookup failed because the renderer URL lookup returned null. The phone frame test passed (it ran on the same library), so this is likely a state issue where switching to desktop mode dropped the library reference.
- Impact: Blocks 6 subsequent preview rendering scenarios

**6. Component Browser UI: Navigate to library detail page**
- FAIL: `h1, h2, [class*='library-name'], [class*='LibraryDetail__name']` not visible
- Root cause: Navigation to the library detail page succeeded (URL changed), but the page has no h1/h2 heading or element matching the expected class patterns. The library detail page likely uses a different naming convention.
- Impact: Blocks 9 subsequent component detail scenarios

### Did not run (57 scenarios)

All 57 are blocked by serial dependency on one of the 6 failed setup/gateway scenarios above. They are NOT implementation failures -- they simply could not be reached.

## QA-side fixes applied

Three test step definitions in `qa/steps/ui-layout.steps.js` had bugs:
1. **Malformed selector**: `"text=/chat/i, [class*='switcher-item']:has-text('chat')"` -- Playwright parsed the comma+regex as an invalid RegExp. Fixed to use `[class*='mode-item']:has-text('chat'), [class*='switcher-item']:has-text('chat')`.
2. **Wrong class pattern for mode selector**: Tests looked for `switcher-item` but HomeView uses `MainLayout__mode-item`. Fixed to include both patterns.
3. **Wrong class pattern for preview selector**: Tests looked for `switcher-item_mobile` but HomeView uses `MainLayout__preview-item`. Fixed to include both patterns.

After fixes: all 3 scenarios now PASS.

## How to run
```bash
bash qa/run-tests.sh              # Run all tests
bash qa/run-tests.sh fast         # Run fast tests (API, auth, health, UI layout, onboarding)
bash qa/run-tests.sh workflow     # Run workflow tests (modal, generation, improvement, preview, browser, export, UI layout)
```

## Analysis: What the Developer got right

The UI redesign implementation is excellent in the following areas:
- Design tokens: all CSS custom properties (--bg-page, --bg-panel, --text-primary, etc.) match the spec
- Typography: system font stack correctly applied, labels are lowercase
- Layout: three-column home page with prompt/DS/preview panels works
- Spacing: 8px grid system, generous border radius (>= 16px on panels)
- Header bar: all 4 control groups present (design selector, mode selector, more button, preview selector)
- Prompt panel: white card, "prompt" label, correct placeholder text
- DS panel: library list with edit links and "new" button
- AI engine bar: "ChatGPT" label, dark pill generate button with white text
- Phone preview frame: 2px border, 72px radius, correct aspect ratio
- Modal overlay: proper z-index layering (>= 100)
- No page scroll: body overflow hidden
- Drag-handle dividers: 2 dividers detected between panels

## Notes
- The `.Preview__frame` issue is the single biggest blocker -- it cascades to block 29 scenarios across 3 features (generation, improvement, export)
- The DS modal import timeout (5 min) may need to be increased to 10 min since Figma imports routinely take 8-10 minutes
- The library detail page navigation issue needs the Developer to check what class/element the page heading uses
- Services need to be running before test execution: Rails on 3000, Vite on 5173, Caddy on 443
- All tests use E2E mode with HS256 JWT tokens (shared secret: "e2e-test-secret-key")
- Base URL: https://design-gpt.localtest.me
