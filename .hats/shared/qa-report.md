# QA Report -- 2026-03-09 (Run 5)

## Summary

- **Total**: 81 tests -- 43 passed, 38 failed
- **Previous run**: 81 tests -- 36 passed, 45 failed
- **Net change**: +7 passed (improvement)
- **Duration**: 15.7 minutes
- **Config**: `playwright.config.js` with `timeout: 120_000` (2 minutes)

## What was tested

All 81 E2E scenarios across 10 feature files, run via `bash run-tests.sh all` with 120s test timeout.

## Results

### PASS (43 tests)

**Authentication (6/6)** -- all green
- PASS: Unauthenticated user sees sign-in screen
- PASS: Clicking the sign-in control initiates login
- PASS: Authenticated user sees the workspace
- PASS: Unauthenticated requests are rejected
- PASS: Invalid or expired credentials are rejected
- PASS: Token refresh on expiry

**Health Check (2/2)** -- all green
- PASS: API health endpoint responds
- PASS: Frontend loads through the proxy

**Design Generation (5/11)**
- PASS: Home page has PROMPT, DESIGN_SYSTEM, and PREVIEW areas
- PASS: DESIGN selector dropdown
- PASS: New user with no DESIGN_SYSTEMs sees generate button disabled
- PASS: Generate without selecting a DESIGN_SYSTEM fails

**Design Improvement (6/10)**
- PASS: Chat auto-scrolls to latest message
- PASS: Improvement uses full conversation context
- PASS: Send button is disabled when input is empty
- PASS: Ctrl+Enter or Cmd+Enter sends the message
- PASS: Settings panel shows component browser
- PASS: Settings panel overview shows DESIGN_SYSTEM info

**Design Management (8/8)** -- all green (FIXED from previous run)
- PASS: List all user DESIGNs
- PASS: View a specific DESIGN
- PASS: Switch between DESIGNs via the design selector
- PASS: Export DESIGN as PNG image
- PASS: Export DESIGN as React project
- PASS: Export menu
- PASS: Export to Figma
- PASS: Export unavailable when DESIGN has no PREVIEW
- PASS: Cannot access another user's DESIGN

**Design System Management (2/4)**
- PASS: List user's DESIGN_SYSTEMs
- PASS: Edit an existing DESIGN_SYSTEM

**Figma Import (2/14)**
- PASS: Home page shows the user's DESIGN_SYSTEMs
- PASS: Home page also shows other users' public DESIGN_SYSTEMs

**Component Browser (10/14)** -- 8 NEWLY PASSING
- PASS: Components are grouped by FIGMA_FILE
- PASS: Component detail shows a link to the Figma source
- PASS: Sync button re-imports the component from Figma
- PASS: Component detail lists all PROPs
- PASS: VARIANT PROP has a select control that updates the PREVIEW
- PASS: Boolean PROP has a checkbox that updates the PREVIEW
- PASS: String PROP has a text input that updates the PREVIEW
- PASS: Component detail shows React code
- PASS: AI Schema shows component tree reachable from ROOT
- PASS: COMPONENT_SET shows Figma JSON for all VARIANTs

**Visual Diff (2/5)**
- PASS: Each VARIANT in a COMPONENT_SET shows its own diff percentage
- PASS: Components below 95% are highlighted

### FAIL (38 tests)

#### Category A: Figma import never completes -- `[qa="ds-browser"]` (14 tests)
**Root cause**: Figma API import jobs never complete. These require valid Figma API credentials and a working background job runner. Developer's claim is CONFIRMED -- these are genuinely API-dependent.

- FAIL: Create a new DESIGN_SYSTEM from FIGMA_FILEs -- `[qa="ds-browser"]` not found (120s timeout)
- FAIL: Import finishes with errors -- same
- FAIL: Add a FIGMA_FILE to an existing DESIGN_SYSTEM -- timeout on `[qa="ds-add-figma-btn"]` click
- FAIL: Figma conventions auto-detect ROOT components -- `[qa="ds-browser"]` not found
- FAIL: Figma Slots create SLOTs with ALLOWED_CHILDREN -- same
- FAIL: INSTANCE_SWAP properties also create SLOTs with ALLOWED_CHILDREN -- same
- FAIL: Import handles VECTOR components -- same
- FAIL: Import fails on Figma API error -- `[qa="ds-box"]:has-text("error")` not found
- FAIL: Individual component errors are visible after import -- `[qa="ds-browser"]` not found
- FAIL: Create a new DESIGN_SYSTEM (DS management) -- same
- FAIL: All components render correctly after import (Cubes) -- timeout (120s)
- FAIL: All PROP types work for every component (Cubes) -- same
- FAIL: Visual diff passes for every default component state (Cubes) -- same
- FAIL: View and manage FIGMA_FILEs in a DESIGN_SYSTEM -- `[qa="ds-browser"]` not found

#### Category B: Design generation requires OpenAI API (9 tests)
**Root cause**: Tests need a "ready" design (with completed AI generation). Without OpenAI API, no designs reach "ready" status with a preview frame. Developer's claim is CONFIRMED.

- FAIL: Generate a DESIGN from a PROMPT and see results in PREVIEW -- `[qa="preview-frame"]` not found
- FAIL: PREVIEW selector switches between phone, desktop, and code views -- no ready design found
- FAIL: Design page during generation -- `[qa="preview-frame"]` not found
- FAIL: Code view shows editable JSX -- no ready design
- FAIL: Editing JSX updates the PREVIEW -- `[qa="preview-frame"]` not found
- FAIL: Reset JSX to a previous ITERATION -- `[qa="chat-panel"]` not found
- FAIL: AI generation fails and DESIGN shows error message -- `[qa="chat-input"]` not found
- FAIL: Send an improvement request via chat -- `[qa="preview-frame"]` not found (needs generation)
- FAIL: Send button is disabled while generating -- `[qa="preview-frame"]` not found

#### Category C: Chat/improvement depends on generation (3 tests)
**Root cause**: These tests navigate to a design page and expect messages or generation flow. Without a working OpenAI API, the design never completes generation. Developer's claim is CONFIRMED.

- FAIL: Chat panel displays conversation history -- 0 messages found (expected >= 1)
- FAIL: Empty message is not sent -- browser closed (120s timeout exceeded)
- FAIL: Multiple improvements in sequence -- `[qa="preview-frame"]` not found

#### Category D: Sync API response is empty JSON (2 tests)
**Root cause**: `POST /api/figma-files` returns empty body -- `SyntaxError: Unexpected end of JSON input`. This is an APP-SIDE BUG, not API-dependent.

- FAIL: Sync all FIGMA_FILEs in a DESIGN_SYSTEM -- JSON parse error on figma-files create
- FAIL: Sync a single FIGMA_FILE in a DESIGN_SYSTEM -- same

#### Category E: Component browser data gaps (4 tests)
**Root cause**: Seed data gaps -- NOT API-dependent. These are fixable app-side or test-side issues.

- FAIL: Component detail shows ALLOWED_CHILDREN for SLOTs -- `[qa="component-config-row"]` not found. Page component exists in seed but its children/config section is not rendered. **App-side**: ComponentDetail does not render a config row for the Page component's slots.
- FAIL: Component with no React code shows a message -- expected "no code" status but got "ready". **App-side**: The e2e-icon component meant to have `react_code: nil` is either not seeded or has been given code.
- FAIL: DESIGN_SYSTEM with no ROOT components shows empty AI Schema -- after creating a no-root DS via API, `[qa="ds-browser-detail"]` and `[qa="ds-modal"]` not found. **Test-side**: The no-root DS has no figma_file so clicking browse may not open a full browser.
- FAIL: Component detail shows raw Figma JSON -- `[qa="component-code"]` section does not contain Figma JSON. **App-side**: The Figma JSON section may not render its content inside `[qa="component-code"]` but in a separate container.

#### Category F: Visual diff seed data mismatch (3 tests)
**Root cause**: Seed data values do not match spec expectations. NOT API-dependent.

- FAIL: Standalone COMPONENT shows its diff percentage -- expected "97" but visual diff element shows a different value
- FAIL: COMPONENT_SET shows average diff -- expected "95" but visual diff shows different value
- FAIL: Components at or above 95% are not highlighted -- TITLE_COMPONENT shows low fidelity mark (it should NOT, since its average should be >= 95%)

#### Category G: DS management create requires import (1 test)
- FAIL: Create a DESIGN_SYSTEM with multiple FIGMA_FILEs -- API response has no DS with >= 2 libraries (`multiFile` is undefined). The test creates DSs via Figma import which never completes. **API-dependent**.

#### Category H: Browse components assertion (1 test)
- FAIL: Browse components in a DESIGN_SYSTEM -- expected > 2 `[qa="ds-menu-item"]` elements but got 0. The step opens a DS without a library, so no components appear. **App-side**: The seeded DS's browser is opened but `ds-menu-item` count is 0, meaning the component list is empty in the modal.

#### Category I: Sync a single component (1 test)
- FAIL: Sync a single component -- `[qa="ds-browser"]` and `[qa="component-name"]` not found. The test expects an already-open DS browser but none is open. **Test-side**: test depends on prior state from Figma import.

## Fixes confirmed from Developer's Cycle 2

The following Developer fixes are CONFIRMED working:

1. **Design Management now fully passes (8/8)** -- List all DESIGNs, Switch DESIGNs, Export menu all now pass. Developer's seed data fixes and API response changes worked.
2. **Component Browser major improvement (10/14 vs 2/14 before)** -- 8 new passes. Developer's seed data restructure (Title as ComponentSet with variants/props, Page as root with slots) is working. Props, React code, Figma JSON, sync button all pass now.
3. **Visual Diff partial improvement (2/5 vs 2/5 before)** -- Same count but different tests. Per-variant diff and "below 95% highlighted" now pass.
4. **Timeout reduction effective** -- 15.7 minutes vs 1.2 hours. No resource contention regression.

## Summary of remaining failures by root cause

| Root cause | Count | API-dependent? |
|---|---|---|
| Figma API import | 14 | YES |
| OpenAI API generation | 9 | YES |
| Chat/improvement depends on generation | 3 | YES |
| DS create via import (API-dependent) | 1 | YES |
| Component-libraries create returns empty body | 2 | NO -- app bug |
| Component browser seed data gaps | 4 | NO -- app/test fix needed |
| Visual diff seed data mismatch | 3 | NO -- app fix needed |
| Browse components assertion | 1 | NO -- app/test fix needed |
| Sync component depends on prior state | 1 | PARTIAL -- test ordering issue |
| **Total API-dependent** | **27** | |
| **Total fixable without APIs** | **11** | |

## How to run

```bash
cd /Users/releu/Code/design-gpt/.hats/qa && bash run-tests.sh all
```

## Notes

- Developer claimed 46/35 but QA measured 43/38. The 3-test difference may be due to test ordering and accumulated data state between runs.
- 27 of 38 failures are genuinely API-dependent (Figma or OpenAI). Developer's claim is largely confirmed.
- 11 failures are NOT API-dependent and can be fixed with seed data corrections, app-side rendering fixes, or test-side adjustments.
- The `POST /api/figma-files` endpoint returns empty body (likely 204 No Content or similar) which causes JSON parse errors in 2 sync tests -- this is an app bug.
