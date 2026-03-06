# QA Status

Last run: 2026-03-06 — all suites fail at `bddgen` (missing step definitions after spec overhaul)

| Suite | Missing steps | Runnable |
|-------|--------------|----------|
| fast (01–02) | 22 | No |
| workflow (03–09) | 231 | No |
| render (10) | 6 | No |

## 01 — Authentication (fast)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Unauthenticated user sees sign-in screen | no step def |
| 2 | ❌ | Clicking the sign-in control initiates login | no step def |
| 3 | ❌ | Authenticated user sees the workspace | no step def |
| 4 | ❌ | Unauthenticated requests are rejected | no step def |
| 5 | ❌ | Invalid or expired credentials are rejected | no step def |
| 6 | ❌ | Token refresh on expiry | no step def |

## 02 — Health Check (fast)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | API health endpoint responds | no step def |
| 2 | ❌ | Frontend loads through the proxy | no step def |

## 03 — Figma Import (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Create a new DESIGN_SYSTEM from FIGMA_FILEs | no step def |
| 2 | ❌ | Import finishes with errors | no step def |
| 3 | ❌ | Home page shows the user's DESIGN_SYSTEMs | no step def |
| 4 | ❌ | Home page also shows other users' public DESIGN_SYSTEMs | no step def |
| 5 | ❌ | Sync all FIGMA_FILEs in a DESIGN_SYSTEM | no step def |
| 6 | ❌ | Sync a single FIGMA_FILE in a DESIGN_SYSTEM | no step def |
| 7 | ❌ | Sync a single component | no step def |
| 8 | ❌ | View and manage FIGMA_FILEs in a DESIGN_SYSTEM | no step def |
| 9 | ❌ | Add a FIGMA_FILE to an existing DESIGN_SYSTEM | no step def |
| 10 | ❌ | Browse components in a DESIGN_SYSTEM | no step def |
| 11 | ❌ | Figma conventions auto-detect ROOT components | no step def |
| 12 | ❌ | Figma Slots create SLOTs with ALLOWED_CHILDREN | no step def |
| 13 | ❌ | INSTANCE_SWAP properties also create SLOTs with ALLOWED_CHILDREN | no step def |
| 14 | ❌ | Import handles VECTOR components | no step def |
| 15 | ❌ | Import fails on Figma API error | no step def |
| 16 | ❌ | Individual component errors are visible after import | no step def |

## 04 — Design System Management (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Create a new DESIGN_SYSTEM | no step def |
| 2 | ❌ | Create a DESIGN_SYSTEM with multiple FIGMA_FILEs | no step def |
| 3 | ❌ | List user's DESIGN_SYSTEMs | no step def |
| 4 | ❌ | Edit an existing DESIGN_SYSTEM | no step def |

## 05 — Design Generation (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Home page has PROMPT, DESIGN_SYSTEM, and PREVIEW areas | no step def |
| 2 | ❌ | Generate a DESIGN from a PROMPT and see results in PREVIEW | no step def |
| 3 | ❌ | PREVIEW selector switches between phone, desktop, and code views | no step def |
| 4 | ❌ | DESIGN selector dropdown | no step def |
| 5 | ❌ | Design page during generation | no step def |
| 6 | ❌ | Code view shows editable JSX | no step def |
| 7 | ❌ | Editing JSX updates the PREVIEW | no step def |
| 8 | ❌ | Reset JSX to a previous ITERATION | no step def |
| 9 | ❌ | New user with no DESIGN_SYSTEMs sees generate button disabled | no step def |
| 10 | ❌ | Generate without selecting a DESIGN_SYSTEM fails | no step def |
| 11 | ❌ | AI generation fails and DESIGN shows error message | no step def |

## 06 — Design Improvement (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Chat panel displays conversation history | no step def |
| 2 | ❌ | Send an improvement request via chat | no step def |
| 3 | ❌ | Chat auto-scrolls to latest message | no step def |
| 4 | ❌ | Improvement uses full conversation context | no step def |
| 5 | ❌ | Send button is disabled while generating | no step def |
| 6 | ❌ | Send button is disabled when input is empty | no step def |
| 7 | ❌ | Ctrl+Enter or Cmd+Enter sends the message | no step def |
| 8 | ❌ | Empty message is not sent | no step def |
| 9 | ❌ | Multiple improvements in sequence | no step def |
| 10 | ❌ | Settings panel shows component browser | no step def |
| 11 | ❌ | Settings panel overview shows DESIGN_SYSTEM info | no step def |

## 07 — Design Management (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | List all user DESIGNs | no step def |
| 2 | ❌ | View a specific DESIGN | no step def |
| 3 | ❌ | Switch between DESIGNs via the design selector | no step def |
| 4 | ❌ | Export DESIGN as PNG image | no step def |
| 5 | ❌ | Export DESIGN as React project | no step def |
| 6 | ❌ | Export menu | no step def |
| 7 | ❌ | Export to Figma | no step def |
| 8 | ❌ | Export unavailable when DESIGN has no PREVIEW | no step def |
| 9 | ❌ | Cannot access another user's DESIGN | no step def |

## 08 — Component Browser (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Components are grouped by FIGMA_FILE | no step def |
| 2 | ❌ | Component detail shows a link to the Figma source | no step def |
| 3 | ❌ | Sync button re-imports the component from Figma | no step def |
| 4 | ❌ | Component detail lists all PROPs | no step def |
| 5 | ❌ | Component detail shows ALLOWED_CHILDREN for components with SLOTs | no step def |
| 6 | ❌ | VARIANT PROP has a select control that updates the PREVIEW | no step def |
| 7 | ❌ | Boolean PROP has a checkbox that updates the PREVIEW | no step def |
| 8 | ❌ | String PROP has a text input that updates the PREVIEW | no step def |
| 9 | ❌ | Component detail shows React code | no step def |
| 10 | ❌ | Component with no React code shows a message | no step def |
| 11 | ❌ | AI Schema shows component tree reachable from ROOT | no step def |
| 12 | ❌ | DESIGN_SYSTEM with no ROOT components shows empty AI Schema | no step def |
| 13 | ❌ | Component detail shows raw Figma JSON | no step def |
| 14 | ❌ | COMPONENT_SET shows Figma JSON for all VARIANTs | no step def |

## 09 — Visual Diff (workflow)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | Standalone COMPONENT shows its diff percentage | no step def |
| 2 | ❌ | Each VARIANT in a COMPONENT_SET shows its own diff percentage | no step def |
| 3 | ❌ | COMPONENT_SET shows the average diff across all VARIANTs | no step def |
| 4 | ❌ | Components below 95% are highlighted | no step def |
| 5 | ❌ | Components at or above 95% are not highlighted | no step def |

## 10 — Complex Figma Compatibility (render)

| # | Status | Scenario | QA Notice |
|---|--------|----------|-----------|
| 1 | ❌ | All components render correctly after import | no step def |
| 2 | ❌ | All PROP types work for every component | no step def |
| 3 | ❌ | Visual diff passes for every default component state | no step def |

---

**Total: 93 scenarios, 0 passing, 93 blocked (missing step definitions)**

Next step: rewrite step definitions to match the new manager spec wording.
