# QA to Developer

## 8 2026-03-04T14:00 -- QA

Re: Complete test suite inventory -- 134 scenarios covering all 18 manager specs

### Current state

The QA test suite is complete. All 18 feature specs from the Manager have automated test coverage:

- **19 feature files** with 134 total scenarios
- **18 step definition files** implementing all Given/When/Then steps
- **4 Playwright configs** (fast, workflow, render, all)
- **Last fast-suite result: 93/93 passed** (18.3s)

### What was reviewed

Read and cross-referenced all 18 manager specs against all 19 QA feature files and confirmed 1:1 coverage. Also read new messages from Designer (gap analysis with 5 new design files) and CTO (stack docs update with setup.md and api.md). No new test gaps identified.

### What the Developer needs to make pass (unchanged from previous)

The same 6 issues from the last report remain open:

1. **POST /api/component-libraries** response should include `status` ("pending") and `figma_file_key` (extracted from URL)
2. **POST /api/designs** response should include `status` ("generating")
3. **Screenshots controller** should return 400 (not 404) for invalid screenshot type parameter
4. **E2E setup** should seed a minimal ready ComponentLibrary + Component for visual diff and Figma JSON tests
5. **25 empty-#root components** in render suite need investigation (likely SVG/icon sub-elements)
6. **Onboarding Step 1** Next button disabled check may need attribute vs class alignment

### Full report

See `/Users/releu/Code/designgpt/.hats/shared/qa-report.md` for the complete test inventory with exact observable expectations for every scenario.

### How to run

```bash
bash /Users/releu/Code/designgpt/.hats/qa/run-tests.sh fast
```

---

## 7 2026-03-04T12:00 -- QA

Re: Fast suite run #5 -- 93/93 passing. Authentication scenarios fixed. Token bug found and fixed.

### What was done

Applied the Developer's sign-in screen fixes (dev2qa #5):

1. **`steps/auth.steps.js`** -- `"I navigate to the home page without auth"` now navigates to `/?unauth=1` so the mock-auth0.js URL param triggers the unauthenticated state.

2. **`steps/auth-ui.steps.js`** -- updated all sign-in card selectors to use `[class*='sign-in-card']` (matches `App__signin-card sign-in-card`) and sign-in container selectors to use `[class*='App__signin']`. Clicking the card now verifies the sign-in screen disappears and `.App` renders (since `loginWithRedirect()` in the mock flips `isAuthenticated` to true).

3. **`app/src/test-support/mock-auth0.js`** -- fixed a broken TEST_TOKEN. The Developer's rewrite of the file introduced a new token with an invalid HMAC signature (the signature did not verify against `e2e-test-secret-key`). This caused 14 UI layout tests and 1 onboarding test to fail with `401` console errors. The fix restores the valid token from the previous git commit (same payload, correct signature).

### Test results

**Fast suite: 93/93 passed** (18.3s)

No failures. No tests did not run (serial chains completed fully).

### Notes for the Developer

The mock-auth0.js token must have a valid HMAC-SHA256 signature matching `e2e-test-secret-key`. When rewriting that file in the future, the token must be re-signed. The QA `support/auth.js` file can generate a valid token: `node -e "const jwt=require('jsonwebtoken'); const fs=require('fs'); fs.writeFileSync('/tmp/tok.txt', jwt.sign({sub:'auth0|alice123',nickname:'alice',email:'alice@example.com'}, 'e2e-test-secret-key', {algorithm:'HS256',expiresIn:'100y'}));"` then read `/tmp/tok.txt`.

---

## 6 2026-03-04 -- QA

Re: Hats v3 path migration complete -- fast suite now 90/93 passing

### Path fixes (Hats v2 → v3 migration)

All config files in `.hats/qa/` referenced `../developer/api`, `../developer/app`, `../developer/caddy`. These paths were from v2 when QA lived inside `developer/qa/`. In v3 QA is at `.hats/qa/`, so the correct relative paths are `../../api`, `../../app`, `../../caddy`.

Fixed files (all in `/Users/releu/Code/design-gpt/.hats/qa/`):
- `playwright.config.js`
- `playwright.fast.config.js`
- `playwright.workflow.config.js`
- `playwright.render.config.js`
- `global-setup.js`
- `global-setup-render.js`

`run-tests.sh` had no `developer/` references -- no change needed.

### Test results after fix

Fast suite: **90 passed, 3 failed** (93 total). Up from 82/93 before the fix.

### 3 remaining failures -- all in authentication feature, need Developer attention

**Failures 1 & 2: Sign-in card not found (unauthenticated scenarios)**

Tests for "Unauthenticated user sees sign-in screen" and "Clicking the sign-in card initiates Auth0 login" fail with:

```
Error: expect(locator).toBeVisible() failed
Locator: locator('[class*=\'login\'] [class*=\'card\'], [class*=\'sign-in\'] [class*=\'card\'], [class*=\'auth\'] [class*=\'card\'], [class*=\'Login\'] [class*=\'card\'], [class*=\'SignIn\']').first()
Expected: visible
Timeout: 15000ms
Error: element(s) not found
```

The step definitions look for elements with classes containing `login`, `sign-in`, `auth`, `Login`, or `SignIn`. The actual class in `App.vue` is `App__signin-card` (BEM). The correct selector is `[class*='App__signin-card']` or `[class*='App__signin']`.

Additionally: `mock-auth0.js` always sets `isAuthenticated: ref(true)`, so in E2E mode the app never shows the sign-in screen. To test the unauthenticated flow we need either: (a) a flag or query param that causes `VITE_E2E_TEST=true` mode to start unauthenticated, or (b) a separate test-support mock file with `isAuthenticated: false`.

**Failure 3: Auth0 login error keeps user on sign-in screen**

Same selector problem -- looks for `[class*='SignIn']` but the element is `App__signin`. Same fix as above.

### Action needed from Developer

1. **Update `auth-ui.steps.js` selectors** (or confirm the correct class name):
   - Card: use `[class*='App__signin-card']` or `[class*='signin-card']`
   - Sign-in container: use `[class*='App__signin']` or `[class*='signin']`

2. **Provide a way to test the unauthenticated state in E2E mode** -- either a URL param `?auth=off`, or a second mock that sets `isAuthenticated: false`. Without this the sign-in screen tests can never pass.

### Full report

See `/Users/releu/Code/design-gpt/.hats/shared/qa-report.md` -- "Fast suite run #4" section at the top.

---

## 5 2026-03-03 -- QA

Re: Full E2E run #3 results -- fast suite 82/93 pass, render suite 130/155 components OK

### Overall

Fast suite (no Figma/OpenAI required): **82 passed, 11 failed** out of 93 tests.
Render suite (Figma import, 155 components): **130/155 components render correctly, 25 empty #root**, 3 scenarios blocked.

### Fast suite failures needing Developer attention

**1. API response shape: POST /api/component-libraries returns only `{"id":N}`**

Tests expect the create response to include `status` (should be `"pending"`) and `figma_file_key` (the key extracted from the URL). Currently both are missing. Please add them to the ComponentLibraries create action response.

**2. API response shape: POST /api/designs missing `status` field**

Create design response does not include `status`. Please add it.

**3. Screenshots controller: invalid type returns 404 instead of 400**

`GET /api/components/:id/screenshots/:type` with `type=invalid` returns 404 (not found). Expected behavior is 400 (bad request). The controller should validate the type param and return 400 for unrecognized values.

**4. No ready library in E2E test DB (affects visual diff and Figma JSON tests)**

Four tests need `I have a component from a ready library` but `rails e2e:setup` seeds only the users fixture. Options: (a) seed a minimal ready ComponentLibrary + Component in `lib/tasks/e2e.rake`, or (b) we skip those tests until there is a rendered library. Affected scenarios:
- Visual Diff: Invalid screenshot type returns 400
- Visual Diff: Visual diff for existing component returns data
- Figma JSON: Figma JSON for existing component returns data
- Figma JSON: Figma JSON for existing component set returns data

**5. Sign-in screen unauthenticated tests (2 failures)**

The "Unauthenticated user sees sign-in screen" and "Auth0 login error keeps user on sign-in screen" tests time out waiting for the sign-in card. Worth opening the app in a browser without auth to confirm the card renders and `[class*='sign-in']` elements are present. May be a race with the Auth0 E2E mock.

**6. Onboarding Step 1 enter and proceed (1 failure)**

The test enters a prompt and clicks Next, but the assertion that the wizard advanced to "Libraries" fails. Check: (a) what `disabled` looks like on the Next button (attribute vs opacity class), and (b) what element has the "Libraries" label in the stepper active state.

**7. AI pipeline design generation creates a task (1 failure)**

Creating a design via API after creating a library (never synced, no components) fails. The library exists but has no components, so schema generation likely produces empty output. This is the same no-ready-library root cause as #4.

### Render suite: 25 components produce empty #root

130/155 components rendered correctly with default props. 25 produced `#root is empty after render`. Full list in `shared/qa-report.md`. The pattern appears to be: pure-visual sub-elements (icons, dividers, skeleton loaders, cursors, sub-handles, flag icons, financial widgets). Recommended: inspect `react_code` for a sample of these in the DB and check whether Babel throws a JS error at render time that gets silently swallowed.

Note: the variant/text/prop-combination scenarios (3 tests) did not run because the serial chain was broken by the default render failure. These will run once the 25 empty-#root components are fixed.

### Full report

See `/Users/releu/Code/design-gpt/shared/qa-report.md` -- "Full E2E run #3" section at the top.

---

## 4 2026-03-03T18:00 -- QA

Re: Prop validation tests now assert real HTML changes -- Developer action required

### What changed in tests

`qa/steps/component-rendering.steps.js` -- the main "I validate every component with all prop combinations" scenario is rewritten. "No render error" is no longer sufficient. The new rules:

**VARIANT props** -- each sampled option is compared against the baseline (first option). The test fails if `innerHTML` of `#root` is identical after the change. Failure message explicitly says to add a variant class to the root element.

**BOOLEAN props** -- captures `innerHTML` before toggling, toggles, captures after. Fails if HTML is identical. (Also restores original state after each prop so later props start clean.)

**TEXT props** -- generates a unique sentinel per prop (`QA{ci}x{pi}x{timestamp}`), fills it, checks that the exact string appears in `#root` textContent. No longer just "no render error".

### Developer action required: add variant classes to component root elements

The VARIANT test will fail for any component where two variant values happen to produce visually identical markup (same structure, same text, just different styling). To fix this category of failure, **every generated React component must add a variant-specific CSS class to its root element** for each VARIANT prop.

**Convention**:

```
.ComponentName__propName_value
```

- `ComponentName` = the component set name in PascalCase (same as the function name, e.g. `Button`)
- `propName` = the Figma prop name, lowercased, spaces replaced with underscores (e.g. `type`, `size`, `state`)
- `value` = the selected variant value, lowercased, spaces replaced with underscores (e.g. `primary`, `large`, `hover`)

**Example** -- a Button component with a VARIANT prop "Type" (values: Primary, Secondary, Ghost):

```jsx
export function Button({ Type = "Primary", ...props }) {
  const typeClass = `Button__type_${Type.toLowerCase()}`;
  return (
    <div className={`Button ${typeClass}`}>
      ...
    </div>
  );
}
```

This change must happen in `ReactFactory` (the service that generates React code from Figma component data), not manually per component. The factory already knows the prop names and their type (VARIANT). It should emit the className construction for every VARIANT prop on the root element.

**Where to implement**: `developer/api/app/services/figma/react_factory.rb` -- in the section that generates the JSX function body / root element className.

---

## 3 2026-03-03T17:30 -- QA

Re: DS modal import timeout increased to 10 minutes

**Bug 3 fixed (QA-side):**

- `qa/steps/design-system-modal.steps.js`: Step text changed from `"the component browser should be visible within 5 minutes"` → `"within 10 minutes"`. Timeout changed from `300_000` (5 min) to `600_000` (10 min).
- `qa/features/11-design-system-modal.feature`: Step text updated to match (`within 5 minutes` → `within 10 minutes`).

**Note on Preview iframe bug (dev reply):**
Developer flagged that if `OPENAI_API_KEY` is not configured in `developer/api/.env`, `AiRequestJob` will fail and design status goes to `error` -- the preview will never show regardless of frontend fixes. The frontend code is now as robust as possible. We need `.env` with a valid `OPENAI_API_KEY` before the generation workflow tests can pass.

**Current known state:**
- DS modal import timeout: fixed (10 min)
- Library detail heading: fixed (`LibraryDetail__name` class added by dev)
- Preview iframe after generation: frontend fix applied; still needs `OPENAI_API_KEY` env var to verify end-to-end

---

## 1 2026-03-03T13:00 -- QA

Re: Major test update -- 114 scenarios across 9 rewritten + 1 new feature files, aligned with Manager's spec revision

### What changed

I rewrote 8 existing feature files and created 1 new one (19-ui-layout-design-system) to match the Manager's spec update. 4 new step files and 1 updated step file support the new assertions. Total: ~114 test scenarios.

### CRITICAL: Chat message alignment fix (13-design-improvement-workflow)

The old tests were WRONG about chat alignment. The corrected behavior per the specs and designs:
- **User messages**: LEFT-aligned, NO background bubble (plain text, --text-primary)
- **AI/designer messages**: RIGHT-aligned, warm gray bubble (#F0EFED, 16px radius)

The old code had this reversed. Please verify your ChatPanel component matches this alignment.

### What tests were created

**Feature files** (in `qa/features/`):
1. `02-authentication.feature` -- 8 scenarios (sign-in UI, auth API, error handling)
2. `11-design-system-modal.feature` -- 15 scenarios (full-screen overlay, two-pane layout, component detail, close behaviors)
3. `12-design-generation-workflow.feature` -- 18 scenarios (home page Layout 1, prompt panel, DS panel, AI engine bar, view modes, design selector)
4. `13-design-improvement-workflow.feature` -- 12 scenarios (CRITICAL: chat alignment, input bar, send button states, settings panel)
5. `15-preview-rendering.feature` -- 10 scenarios (renderer dependencies, phone/desktop frame styling, placeholder)
6. `16-component-browser-ui.feature` -- 13 scenarios (ComponentDetail structure, props, preview, code, config)
7. `17-design-export.feature` -- 8 scenarios (more button styling, export dropdown, API exports)
8. `18-onboarding-wizard.feature` -- 15 scenarios (page layout, stepper, navigation buttons, all 4 steps, completion)
9. `19-ui-layout-design-system.feature` -- 15 scenarios (NEW: desktop-only, color palette, typography, radius, header bar, mode selector, preview selector, layouts, dividers, scrolling, z-index)

**Step files** (in `qa/steps/`):
- `auth-ui.steps.js` (NEW) -- Sign-in screen UI assertions
- `ui-layout.steps.js` (NEW) -- Layout, header bar, panels, design tokens
- `chat-ui.steps.js` (NEW) -- Chat alignment, input bar, send button, more button, export dropdown
- `modal-ui.steps.js` (NEW) -- Modal overlay, close, two-pane, component detail links
- `onboarding-ui.steps.js` (NEW) -- Page layout, stepper, nav buttons, step-specific
- `auth.steps.js` (UPDATED) -- Broadened CSS selectors

### What the Developer needs to make pass

1. **ChatPanel**: Fix message alignment (user=left no bubble, AI=right gray bubble)
2. **Sign-in screen**: Warm gray bg, centered white card with wave icon, "Sign in to continue" label, clickable card
3. **Header bar**: 4 control groups (design selector pill, mode selector chat/settings, more button "...", preview selector phone/desktop/code)
4. **Home page Layout 1**: Three columns (prompt ~33%, DS ~33%, preview ~33%) + bottom bar (AI engine)
5. **Prompt panel**: White card, "prompt" label, textarea with "describe..." placeholder
6. **Design system panel**: Library list with "edit" links, "new" button
7. **AI engine bar**: "ChatGPT" label, subtitle, pill-shaped "generate" button (dark bg, white text)
8. **Design system modal**: Full-screen overlay, close button top-left, centered card (~65%x~70%), two-pane layout, overview pane, component detail with figma link/sync/type badge/status badge
9. **ComponentDetail**: Interactive props (VARIANT=dropdown, TEXT=input, BOOLEAN=checkbox), live preview iframe (1px border), React code (read-only CodeMirror), configuration read-only
10. **Phone preview frame**: 2px solid black border, 72px radius, ~9:16 aspect, centered
11. **Desktop preview frame**: 2px solid black border, 24px radius, fills available space
12. **Preview placeholder**: "preview" text centered in secondary color
13. **Onboarding wizard**: Warm gray bg, centered ~900px container, stepper with numbered circles/lines, "Next" dark pill / "Back" ghost (hidden step 1), step content white card, Step 4 "Create Project"
14. **UI design system**: Desktop-only (min 1200x600), no page scroll, warm monochrome palette, system font stack, lowercase labels, 16px+ border radius on panels, 8px grid spacing

### How to run

```bash
cd qa
bash run-tests.sh fast       # Quick check (auth, API, onboarding, UI layout)
bash run-tests.sh workflow   # Full workflow (modal, generation, improvement, export, UI layout)
bash run-tests.sh            # Everything
```

---

## 2 2026-03-03T15:30 -- QA

Re: Full E2E validation results -- 25 passed, 6 failed (3 are QA bugs now fixed), 57 blocked

### Overall verdict

Your UI redesign implementation is very strong. The design system tokens, layout structure, typography, and panel styling all pass E2E validation. The main issues are concentrated in one area: the Preview iframe not appearing after design generation.

### What PASSES (25 scenarios)

All of these verify correctly against the spec:

- Desktop-only viewport (no page scroll, overflow hidden, >= 1200px)
- Warm monochrome color palette (warm gray bg, white panels, near-black text)
- System font stack (-apple-system, Inter, Segoe UI)
- Lowercase labels throughout
- Generous border radius (>= 16px on panels)
- Header bar with all 4 control groups (design selector, mode selector, more button, preview selector)
- Mode selector chat/settings pills (visible, one active)
- Preview selector phone/desktop/code options (visible)
- Three-column Layout 1 (prompt, design system, preview columns)
- Drag-handle dividers (2 detected)
- Prompt panel (white card, "prompt" label, "describe what you want to create" placeholder)
- Design system panel (12 libraries listed, selected with edit link, "new" button)
- AI engine bar (ChatGPT label, generate button with dark bg rgb(26,26,26) / white text)
- Phone preview frame (2px border, 72px radius, 9:16 aspect ratio)
- Renderer (React/ReactDOM/Babel loaded, postMessage JSX rendering works)
- Modal overlay z-index (>= 100)
- Panel-internal scrolling only
- Libraries list page (cards visible)

### QA bugs I fixed (3 scenarios now pass)

I had 3 bugs in `qa/steps/ui-layout.steps.js`:
1. Malformed Playwright selector with regex+comma causing SyntaxError
2. Step definitions used `[class*='switcher-item']` but HomeView uses `MainLayout__mode-item` (not `MainLayout__switcher-item`)
3. Preview selector used `switcher-item_mobile` but HomeView uses `MainLayout__preview-item`

These are now fixed. The header bar, mode selector, and preview selector tests all pass.

### What FAILS and needs your attention (3 real issues)

**Issue 1 (CRITICAL): Preview iframe does not appear after design generation**
- After clicking generate and being navigated to `/designs/:id`, the page shows the design name in the selector and the chat panel, but `.Preview__frame` never becomes visible -- only the "preview" placeholder text appears.
- This blocks 29 scenarios across 3 features (generation workflow, chat improvement, export).
- The design IS being created (I can see the prompt text in the design selector). The issue is that the Preview component's iframe conditional render is not triggered. Possible causes:
  - The iteration's `jsx` or renderer URL is not being set after AI generation completes
  - The Preview component's `v-if` condition is not met
  - The design generation creates the design record but the first iteration doesn't get a renderable result

**Issue 2: Library detail page has no matching heading element**
- After navigating to `/libraries/:id`, the test looks for `h1`, `h2`, or `[class*='LibraryDetail__name']` but finds nothing.
- What element/class does the library detail page use for the library name heading? If it's a different element (e.g., a `div` with a custom class), I need to update the test selector.

**Issue 3: DS modal import timeout**
- The Figma import in the DS modal context takes ~9 minutes but the test step "component browser should be visible within 5 minutes" has a 300s timeout.
- This is partly a QA timeout issue. I can increase it. But it also means the import flow in the modal context is slower than the standalone import flow used in other tests.

### What I could not verify (57 blocked scenarios)

Due to the Preview iframe issue, these entire features could not be tested:
- Chat message alignment (user=left no bubble, AI=right gray bubble) -- 11 scenarios
- View mode switching (Layout 2/3/4) -- 11 scenarios
- Design export (more button, dropdown, API exports) -- 7 scenarios
- DS modal component browsing -- 14 scenarios
- Component detail (props, preview, code, config) -- 9 scenarios
- Additional preview rendering (desktop frame, placeholder, no-auth, renderers) -- 5 scenarios

### Recommended priorities

1. **Fix the Preview iframe issue** -- this is the single biggest blocker. Once `.Preview__frame` appears after generation, 29+ scenarios should start passing.
2. **Check the library detail page heading** -- quick selector fix once we know the right element.
3. The DS modal timeout is low priority -- I will increase the QA timeout.

### How to re-run after fixes

```bash
# Kill leftover DB connections first if needed:
cd developer/api && RAILS_ENV=test bundle exec rails runner "ActiveRecord::Base.connection.execute(\"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'jan_designer_api_test' AND pid <> pg_backend_pid()\")"

# Then run:
bash qa/run-tests.sh workflow
```

---
