# QA Report — 2026-03-07 (Run 3)

## Summary

- **Fast tests**: 8 passed, 0 failed
- **Workflow tests**: 42 passed, 28 failed (53.8 min)
- **Total**: 50 passed, 28 failed

Compared to Run 2 (46 passed, 32 failed): **4 fewer failures**. Developer fixes #12 resolved the `.first()` bug, seed data gaps, design creation 422, and `allowed_children` → `slots` migration.

## Failures by category

### Category A: Figma import — needs FIGMA_ACCESS_TOKEN (11 tests)

All 11 tests in `03-figma-import.feature` require real Figma API access. These will fail without FIGMA_ACCESS_TOKEN configured.

Tests: Create DS from Figma files, Sync all/single file/component, Add file to DS, auto-detect ROOT, Figma Slots, INSTANCE_SWAP, VECTOR, Figma API error, individual component errors

### Category B: Design system management — depends on Figma import (1 test)

- **Create a new DESIGN_SYSTEM** — triggers Figma import flow, times out without FIGMA_ACCESS_TOKEN

### Category C: Design generation — needs OPENAI_API_KEY + UI fixes (9 tests)

Tests in `05-design-generation.feature`:

| Test | Root cause |
|------|-----------|
| Home page has PROMPT, DESIGN_SYSTEM, PREVIEW areas | UI selector mismatch — page renders correctly but test selectors don't match |
| Generate a DESIGN from PROMPT | Needs OPENAI_API_KEY |
| PREVIEW selector switches views | Needs OPENAI_API_KEY (no design to preview) |
| Code view shows editable JSX | Needs OPENAI_API_KEY |
| Editing JSX updates PREVIEW | Needs OPENAI_API_KEY |
| Reset JSX to previous ITERATION | Needs OPENAI_API_KEY |
| Generate button disabled for new user | E2E user (alice) has seeded DS, so button is never disabled |
| AI generation fails shows error | Needs OPENAI_API_KEY to test error path |

### Category D: Design improvement — needs OPENAI_API_KEY (3 tests)

Tests in `06-design-improvement.feature`:
- Chat panel displays conversation history — needs a generated design
- Empty message is not sent — timeout
- Multiple improvements in sequence — needs generated design

### Category E: Design management — UI selector issues (3 tests)

Tests in `07-design-management.feature`:
- **List all user DESIGNs** — test creates designs via API but ordering assertion may be timing-dependent
- **Switch between DESIGNs via design selector** — expects >= 3 options in selector dropdown
- **Export menu** — expects `.MainLayout__export-menu` or `.MainLayout__dropdown` class

### Category F: Component browser — data/selector issues (2 tests)

- **Component with no React code shows "no code"** — E2E seed component has status "ready" but test expects "no code". Need a component without react_code in seed data.
- **DS with no ROOT shows empty AI Schema** — `.DesignSystemModal__browser-detail` not found on page

## What improved since Run 2

1. **`.first()` on expect bug** — Fixed in design-management.steps.js and component-browser.steps.js (was Category D in Run 2)
2. **Seed data: Title + Page components** — e2e.rake now seeds components with BOOLEAN/TEXT prop_definitions and slots
3. **Design creation 422** — Fixed `Given("the user has {int} DESIGNs")` to send `design_system_id` instead of empty `component_library_ids`
4. **`allowed_children` → `slots`** — Fixed Background step in design-generation.steps.js

## Priorities for Developer

### P1 — Seed a "no code" component for browser test (1 test)

The component browser test expects a component with status "no code" (no react_code). All E2E seed components have react_code. Add one component to e2e.rake with `react_code: nil, status: "imported"` (or whatever status indicates no code).

### P2 — Generate button disabled test isolation (1 test)

The test "New user with no DESIGN_SYSTEMs sees generate button disabled" creates a fresh user token but the home page auto-selects a DS. Either: (a) the step should verify via API that the new user truly has zero DSes, or (b) the app should not auto-select a DS for users who haven't created one.

### P3 — Design management selector count (1 test)

"Switch between DESIGNs" expects >= 3 options in the design selector (2 designs + "new"). The setup creates 2 designs but the selector may only show the current design + "new" = 2 options.

## Environment-dependent tests (15 total)

- 12 Figma import tests (Categories A + B) — need FIGMA_ACCESS_TOKEN
- 7+ Design generation/improvement tests (Categories C + D) — need OPENAI_API_KEY

These cannot pass without external API keys configured. They are not Developer bugs.

## How to run

```bash
bash .hats/qa/run-tests.sh fast        # 8 tests, ~8s
bash .hats/qa/run-tests.sh workflow    # 70 tests, ~54min
```

## Notes

- Base URL: https://design-gpt.localtest.me
- Auth: HS256 JWT signed with `e2e-test-secret-key` (E2E_TEST_MODE=true)
- Test user: auth0|alice123 / alice@example.com
- Figma import tests require FIGMA_ACCESS_TOKEN in api/.env
- Design generation tests require OPENAI_API_KEY in api/.env
