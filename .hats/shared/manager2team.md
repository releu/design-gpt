# Manager to Team

## [11] 2026-04-23T00:00 -- Manager

Re: New Figma convention — `#flexgrow` description tag

Two new scenarios added to `03-figma-import.feature` under the "Figma Conventions" section.

**Convention:** a component with `#flexgrow` in its Figma description generates CSS containing `flex-grow: 1`.

**Scope:**
- Top-level component only (not nested child nodes)
- Value is always `flex-grow: 1` (no parametric forms like `#flexgrow-2`)
- No validation warning if the parent isn't a flex container — it's the DS author's responsibility
- Mixing with other tags (`#root`, `#image`) is undefined; not specified in the spec

**Verification:** QA asserts against `[qa="component-code"]` (the component source view).

**Next:** QA writes step defs and a test fixture; Developer implements the parse-and-emit in the import pipeline.

---

## [10] 2026-04-22T13:00 -- Manager

Re: DS sync notification — "rebuild design" chat message with AI re-generation

### Problem

When a design system is synced (components re-imported from Figma), existing designs that use that DS become stale. The component API may have changed — new props, renamed variants, different slots. The generated JSX references the old component structure. The user has no way to know this happened and no easy way to update their design.

### Feature

After a design system sync completes successfully, every design linked to that DS receives a **system chat message** prompting the user to rebuild. The message includes a button that triggers an AI re-generation, preserving the current design intent while adapting to the updated component API.

### User flow

1. User syncs their design system (or it syncs automatically)
2. Sync completes — all Figma files are re-imported and converted
3. Every design linked to that DS gets a new chat message:
   - Author: `"system"` (new author type — not user, not designer)
   - Message: `"Design system was updated. Components may have changed."`
   - A **"Rebuild design"** action button visible in the chat
4. User clicks "Rebuild design"
5. The design enters `"generating"` state
6. AI receives the **previous iteration's JSON tree** (not JSX) plus a system instruction: "The component library has been updated. Rebuild this design using the current component API. Preserve the layout and content as closely as possible."
7. A new iteration is created with updated JSX
8. Preview updates with the rebuilt design

### Data model changes

**ChatMessage** — new `author` value:
- Add `"system"` as a valid author (alongside `"user"` and `"designer"`)
- System messages are visually distinct from both user and AI messages in the frontend

**ChatMessage** — new `action` field:
- Add `action` string column (nullable, default nil)
- When `action: "rebuild"`, the frontend renders a clickable button
- After the user clicks, the message should update to reflect the action was taken (e.g. action becomes `"rebuild_started"`)

### Backend changes

**DesignSystem sync completion hook** — after DS status becomes `"ready"` in `FigmaFileConvertJob#maybe_finalize_design_system`:
- Find all designs linked to this DS: `Design.where(design_system_id: ds.id)`
- For each design, create a system chat message with `author: "system"`, `action: "rebuild"`
- This should be a background job (`DsUpdateNotifyJob`) to avoid slowing down the sync pipeline

**New API endpoint** — `POST /api/designs/:id/rebuild`:
- Requires auth (uses `find_user_design`)
- Takes no body params
- Creates a new iteration with comment: `"Rebuild after design system update"`
- Sends to AI with the last iteration's **tree** (JSON, not JSX) and an instruction to preserve the design while adapting to the updated component API
- Returns 200 with design JSON

**Design#rebuild method**:
- Similar to `Design#improve` but instead of a user prompt, sends a structured rebuild instruction
- The AI context includes: the previous tree JSON, the instruction to preserve layout/content, and the updated component schema
- The chat message for the AI response should be `author: "designer"` as usual

### Frontend changes

**ModuleChat.vue** — render system messages:
- New visual style for `author: "system"` messages — centered, muted color, smaller text (like a system notification, not a chat bubble)
- When `msg.action === "rebuild"`: render a button labeled "Rebuild design"
- When `msg.action === "rebuild_started"`: show "Rebuilding..." (disabled) or hide the button
- Button click calls `POST /api/designs/:id/rebuild`, then triggers `fetchDesign()` to start polling

### AI prompt for rebuild

The rebuild prompt to the AI should be structured as:

```
The design system components have been updated. Rebuild the following design 
using the current component API. Preserve the layout, content, and structure 
as closely as possible. If a component or prop no longer exists, find the 
closest equivalent.

Previous design (JSON tree):
{previous iteration tree JSON}
```

This goes as the user message. The system prompt (with updated component schema) is built normally by `DesignGenerator`.

### Implementation notes

- The rebuild uses the **tree** (structured JSON), not the JSX string, because tree is more meaningful for the AI — it contains component names, prop values, and slot structure that map directly to the schema
- If a design has no iterations with a tree, skip the notification (nothing to rebuild)
- The `DsUpdateNotifyJob` should only notify designs with status `"ready"` (not drafts or designs currently generating)
- System messages should not trigger polling (they're not AI responses)

### Action required

**Developer** (`/hats:developer`):
1. Add migration: `action` column on chat_messages, allow `"system"` as author
2. Create `DsUpdateNotifyJob` — enqueued after DS sync completes
3. Create `POST /api/designs/:id/rebuild` endpoint and `Design#rebuild` method
4. Update `ModuleChat.vue` to render system messages with rebuild button
5. Wire up button click → API call → polling

**QA** (`/hats:qa`): New scenarios needed for rebuild flow.

---

## [9] 2026-03-17T18:00 -- Manager

Re: Component validation warnings — specs updated across import, browser, generation, and image workflow

### Summary

Components that fail validation for their convention (e.g. `#image` with children) were previously rejected or silently dropped. Now they are **imported with validation warnings** — visible to the user but excluded from AI generation.

### Spec changes (4 files)

1. **`03-figma-import.feature`** — Replaced 3 image rejection scenarios with warning scenarios. Added general validation warnings section covering: glass effects, overflowing children without clipping, skewed/distorted transforms, scrolling content, and fixed-position elements. Any component with warnings is imported but flagged.

2. **`05-design-generation.feature`** — New section "Validation Warnings": components with validation warnings are excluded from the AI schema and cannot be used in generated designs.

3. **`08-component-library-browser.feature`** — New section "Validation Warnings": components with warnings show a warning indicator in the list, and the detail view displays the warning messages so users know what to fix in Figma.

4. **`11-image-workflow.feature`** — Updated "Invalid #image component structure" scenario: component is now imported with `is_image: true` plus validation warnings, excluded from AI schema. No longer silently dropped.

### Implementation notes

**Database**: Add a `validation_warnings` column (JSONB, default `[]`) to both `components` and `component_sets` tables. Each entry is a plain string describing one validation issue.

**Importer**: During import, run validation checks on all components. Instead of skipping invalid components, import them and populate `validation_warnings`. Validations:
- `#image` convention: no children, no component properties, no corner radius
- General (all components): no glass effects, no overflowing children without clipping, no skewed/distorted transforms, no scrolling content, no fixed-position elements
- Note: test frame validation in `figma2react_test.rake` already detects glass, overflow, and skew — reuse that logic

**API**: Expose `validation_warnings` in component/component_set JSON responses. No new endpoints needed.

**AI Schema**: Filter out components where `validation_warnings` is non-empty when building the schema for generation.

**Frontend**: Show a warning badge/indicator on components with non-empty `validation_warnings` in the component list. In the detail view, render the warnings as a list.

### Action required

**CTO** (`/hats:cto`): Confirm the `validation_warnings` JSONB column approach.

**Developer** (`/hats:developer`): Implement the migration, importer changes, API exposure, AI schema filtering, and UI indicators.

**QA** (`/hats:qa`): Update E2E tests to match the new warning behavior (components imported with warnings, not rejected).

---

## [8] 2026-03-17T12:00 -- Manager

Re: Post-implementation spec sync — 6 specs updated, 1 new spec created

### Summary

Feature specs were last overhauled on March 6. Since then, 11 days of development shipped major new capabilities without updating specs. This update brings specs in line with reality.

### Updated Specs (6)

1. **`03-figma-import.feature`** — Added `#image` convention: components with `#image` in name or description are marked as IMAGE components. IMAGE components are excluded from SLOT ALLOWED_CHILDREN lists. Two new scenarios.

2. **`04-design-system-management.feature`** — Added public design systems (is_public flag, visible to other users, view-only for non-owners). Added versioning (sync increments version, iterations render with their original version). Added sync concurrency guard (one sync at a time per design system). Six new scenarios.

3. **`05-design-generation.feature`** — Added IMAGE components in generation: AI places search queries as INSTANCE_SWAP props, preview renders as div+background-image via /api/images/render endpoint. Two new scenarios.

4. **`07-design-management.feature`** — Added shared design links: iterations have share codes, designs viewable without auth via /share/:share_code, exports (React + Figma) work from shared URLs without auth. Three new scenarios.

5. **`08-component-library-browser.feature`** — Added IMAGE component display in browser alongside ROOT and VECTOR conventions. One new scenario.

6. **`11-image-workflow.feature`** — Expanded from API-only to full pipeline: Figma convention (#image tag), web preview rendering (div + CSS background-image), Figma plugin fill pipeline. Restructured into three sections.

### New Spec (1)

7. **`12-figma-export.feature`** — Figma plugin export flow. Share code generation, export-figma API endpoint (no auth via share_code, auth via design ID), plugin tree rendering (component instances, text/variant/boolean properties, slot children, IMAGE fills). Eleven scenarios.

### Action required: Glossary + Test Contract updates

The Manager role cannot write to glossary.md or test-contract.md. **CTO or Developer** — please apply these changes:

#### glossary.md additions

Add to "Design System & Components" table:
| **Image Component** | A component tagged with `#image` in its description in Figma. Must be a plain frame with a background fill and no children — components with child nodes or component properties (variant, boolean, text) are not valid image components. Acts as an AI-driven image placeholder — the AI places search query strings as props, and the preview/plugin fetches matching images at render time. |

Update "Root Component" definition: conventions (`#root`, `#image`) are detected in the component **description only**, not the name.

Update "Iteration" definition to mention it stores `design_system_version` for rendering with correct library version.

Add to "Design Generation" table:
| **Share Code** | A short unique alphanumeric code assigned to each iteration. Used to share designs via public URLs and to export to Figma via the plugin. No authentication required to access shared content. |
| **Design System Version** | An integer that increments on each sync. Components belong to a specific version. Iterations record which version they were generated with, ensuring previews render with the correct components even after later syncs. |

#### test-contract.md additions

Add these API endpoints:

| GET | /api/share/:share_code | -- | `200 { id, name, share_code, iteration_id, jsx }` |
| GET | /api/iterations/:share_code/export-figma | -- | `200 { design_id, name, tree, jsx }` |
| GET | /api/iterations/:share_code/export-react | -- | `200 application/zip` |
| GET | /api/designs/:id/export-figma | -- | `200 { design_id, name, tree, jsx, design_system_id }` |

Note: All iteration share_code endpoints are **public (no auth required)**. The design export-figma endpoint uses `find_accessible_design` (public access).

Also add to Behaviors section:

**Figma Export (12-figma-export.feature)**
- Export to Figma via share code: `[qa="export-btn"]` opens `[qa="export-menu"]`, "Export to Figma" shows share code
- Public export-figma endpoint: GET /api/iterations/:share_code/export-figma → 200 with enriched tree (no auth)
- Design export-figma: GET /api/designs/:id/export-figma → 200 with tree + design_system_id

**Image Workflow (11-image-workflow.feature)** — update existing section:
- Add: `#image` convention detected on import → is_image boolean on component/component_set
- Add: image components excluded from slot allowed_children

### Specs confirmed unchanged

- 01-authentication, 02-health-check, 06-design-improvement, 09-visual-diff, 10-complex-figma-compatibility — no changes needed.

---

## 1 2026-03-03T12:00 -- Manager

Re: Major spec update -- aligned all feature specs with designer's 8 design description files

After reviewing all 8 design descriptions (01-global-design-system through 08-onboarding-wizard) against the 17 existing feature specs, I have updated 8 specs and created 1 new spec. Here is what changed and why.

### CRITICAL FIX

**`06-design-improvement.feature`** -- Chat message alignment was WRONG. The old spec said "user messages right-aligned with orange background, designer messages left-aligned with gray background." The designs show the OPPOSITE: user messages are LEFT-aligned with NO bubble (plain text), and AI/designer messages are RIGHT-aligned in a warm gray bubble (#F0EFED, 16px radius). This has been corrected. All chat UI detail has been added: pill-shaped input bar (~44px, --radius-pill, light gray bg), solid black circle send button (~32px), gravity-anchored messages (empty space above), Cmd+Enter for Mac, send button disabled states (empty input AND during generation).

### Updated Files (8)

1. **`01-authentication.feature`** -- Added sign-in screen UI detail from design 03: wave icon on centered white card (~120x120px, 16px radius, shadow), warm gray background, "Sign in to continue" label. Added click-to-login scenario. Added Auth0 error handling scenario. Updated authenticated-user scenario to check for header bar, prompt panel, design system panel, AI engine bar, and preview frame (not just "prompt area" and "design system selector").

2. **`03-figma-import.feature`** -- Added UI scenarios from design 06 (modal overview pane): "add figma file" input with "add" button, import progress visible in modal, "open" and "remove" links on file list items, "sync with figma" action link, sync failure error display in modal.

3. **`04-design-system-management.feature`** -- Major rewrite. Added full-screen modal overlay structure: --bg-modal-overlay background, close (x) button in top-left of overlay (~36px circle), centered modal card (~65% x ~70% viewport, 24px radius, shadow). Added two-pane layout detail: left navigation sidebar (~35%) with general/overview and Figma-file-organized component tree, right content area (~65%). Replaced "clicks Save" with auto-save on blur/close. Added close-on-overlay-click. Added per-component Figma link and sync. Added ComponentDetail sections: name (16px bold), type badge, status badge, props with type-dependent controls, live preview iframe, React code (read-only CodeMirror), configuration (read-only root + children).

4. **`05-design-generation.feature`** -- Significant expansion. Added home page three-column layout (Layout 1) with exact proportions and drag-handle dividers. Added prompt panel detail (white card, 24px radius, "prompt" label, placeholder text). Added design system panel detail (library list with "edit" links, "new" button). Added AI engine bar detail (ChatGPT label, subtitle, pill-shaped generate button with dark bg). Added all four layout modes for the design page: Layout 2 (phone=two columns 60/40), Layout 3 (desktop=stacked with horizontal divider), Layout 4 (code=three columns 25/42/33 with code editor + phone preview). Updated design selector dropdown detail. Added generating state with disabled send button. Fixed placeholder text from "Generated design will appear here" to "preview" (matching designs).

5. **`07-design-management.feature`** -- Added design selector pill shape detail (caret/chevron, ~160px min width, ~36px height), dropdown styling (white card, 16px radius, shadow, items 14px with hover highlight, "(+) new design" always first). Added more button detail (three dots, no border/bg, ~36x36px clickable area, center-right position). Added export dropdown styling (white card, 16px radius, shadow).

6. **`08-component-library-browser.feature`** -- Added shared ComponentDetail view structure used across three contexts (modal, settings panel, library detail page). Added component header detail: name 16px bold, "link to figma" link, "sync with figma" action, type badge (pill), status badge with color coding. Added live preview iframe detail (1px solid border, full width, ~200-300px height). Added React code section (read-only CodeMirror, monospace, JSX highlighting). Clarified configuration is read-only (set by Figma conventions).

7. **`11-onboarding-wizard.feature`** -- Added page layout detail (warm gray bg, centered ~900px container, 32px padding). Added stepper visual detail: numbered circles connected by horizontal lines, completed=filled circle + solid line, active=filled with ring emphasis + bold label, upcoming=outline circle + dashed line. Added navigation button styling: "Next"=dark pill, "Back"=ghost/outline (hidden on Step 1), "Create Project" label on Step 4. Added step content white card (24px radius, 24px padding). Added Step 2 row detail (checkbox, name, status badge, component count, import input). Added Step 3 grouping (Component Sets section + Standalone Components section with counts). Added Step 4 tag-based UI for children (pill tags with [+] add and (x) remove).

8. **`12-preview-rendering.feature`** -- Added phone frame details: 2px solid black border, ~9:16 portrait aspect ratio, horizontal/vertical centering in column, notch indicator extending to column divider. Added desktop frame: 2px solid black border, 24px radius, fills available space. Fixed placeholder text to "preview" (was inconsistent). Added internal scrolling note.

### New File (1)

9. **`18-ui-layout-and-design-system.feature`** -- New spec covering cross-cutting UI patterns not previously captured:
   - Desktop-only constraint (min 1200x600, no mobile breakpoints)
   - Warm monochrome color palette (all tokens: --bg-page, --bg-panel, --text-primary, etc.)
   - Typography scale (14px body, 13px labels, 12px captions, 13px mono code, all lowercase labels)
   - 8px grid spacing system (sp-1 through sp-6)
   - Border radius system (8/16/24/pill/72px)
   - Minimal shadows and borders
   - Header bar structure (4 control groups: design selector, mode selector, more button, preview selector)
   - Mode selector toggle (chat/settings, mutually exclusive, active=filled)
   - Preview selector toggle (phone/desktop/code, mutually exclusive)
   - Four layout patterns (L1=three columns+bottom bar, L2=two columns, L3=stacked, L4=three columns)
   - Drag-handle dividers (1px line, bar indicator, col-resize/row-resize cursor, panel resize)
   - Module panel pattern (white, 24px radius, 16px padding, label above content)
   - Interactive states (hover, active, disabled, focus)
   - Animation defaults (150ms panels, 100ms chips, 200ms modals, instant navigation)
   - Panel-internal scrolling only (no page scroll)
   - Z-index layers (0=base, 100=dropdown, 200-201=modal, 300=toast)

### Files NOT changed (9)

- `02-health-check.feature` -- Infrastructure only, no design impact.
- `09-custom-components.feature` -- API-only spec, no UI in designs.
- `10-visual-diff.feature` -- Backend comparison, no design impact.
- `13-component-rendering-validation.feature` -- Validation spec, no design impact.
- `14-ai-task-pipeline.feature` -- Backend pipeline, no design impact.
- `15-component-svg-assets.feature` -- Asset serving, no design impact.
- `16-figma-json-inspection.feature` -- Debug endpoint, no design impact.
- `17-image-search.feature` -- Search endpoint, no design impact.

### Suggested next steps

- **Developer**: Review updated specs before starting implementation, especially the chat alignment fix and the new Layout/UI spec (18).
- **QA**: Updated specs provide much more testable UI criteria. Generate or update test cases from the new scenarios.
- **Designer**: No action needed -- specs now align with your design descriptions.

---

## 3 2026-03-03T23:30 -- Manager

Re: BREAKING — Hats upgraded v2 → v3, `developer/` eliminated, code is now at project root

### What changed

The Hats library was upgraded from **v2 to v3**. The project file structure changed:

**v2 structure (OLD):**
```
developer/        ← code lived here
  api/
  app/
  caddy/
  e2e/
manager/          ← hats dirs at project root
qa/
shared/
status.json
```

**v3 structure (NEW, current):**
```
api/              ← code is now at project root (no developer/ prefix)
app/
caddy/
e2e/
.hats/            ← ALL hats dirs moved into .hats/
  manager/
  qa/
  shared/
  designer/
  cto/
  status.json
```

The `.hats/` directory restructure is **already complete**. The `developer/` directory no longer exists.

### Action required by QA

**All 6 QA config/setup files reference `../developer/api`, `../developer/app`, `../developer/caddy` — these paths are broken.** Since QA is now at `.hats/qa/`, the correct relative paths are:

| Old (broken) | New (correct) |
|---|---|
| `../developer/api` | `../../api` |
| `../developer/app` | `../../app` |
| `../developer/caddy` | `../../caddy` |

Files to fix:
- `.hats/qa/playwright.config.js`
- `.hats/qa/playwright.fast.config.js`
- `.hats/qa/playwright.workflow.config.js`
- `.hats/qa/playwright.render.config.js`
- `.hats/qa/global-setup.js`
- `.hats/qa/global-setup-render.js`

Also fix `run-tests.sh` if it has any `developer/` references.

### Action required by CTO

Update `.hats/shared/tech-stack.md` — the "Project Structure" section still shows the old `developer/` layout. Update it to reflect code at project root.

### Action required by Developer

No code changes needed — the code was already at the correct locations (`api/`, `app/`, `caddy/`). Just be aware that any path references in messages or comments saying `developer/api/...` or `developer/app/...` should be read as `api/...` and `app/...` respectively.

The ongoing work from the previous sprint (QA run #3 issues: 11 fast-suite failures + 25 empty-#root components) continues after the path fix is applied.

---

## 4 2026-03-04T20:00 -- Manager

Re: PRIORITY DIRECTIVE -- All 51 skipped workflow E2E tests must be unskipped, fixed, and passing

### The directive

The product owner has made this clear: **the 51 skipped workflow E2E tests are now the number one priority for the entire team.** The first part of this project cannot be considered complete until every single E2E test -- fast suite AND workflow suite -- is green. No exceptions.

### What is not acceptable

- **Skipping tests because they are slow.** "It takes 20 minutes to run" is not a valid reason to skip a test. If a test covers real user-facing behavior (Figma import, React conversion, design generation, chat, export), it must run and it must pass.
- **Leaving tests in a "skipped" or "blocked" state.** Every scenario in the workflow suite must be unskipped and passing. If a test cannot pass because of a real bug, the bug must be fixed -- not the test removed.
- **Declaring victory on fast-suite-only results.** 93/93 fast is necessary but not sufficient. The workflow suite covers the core value proposition of this product: Figma components become live React previews through AI generation. That pipeline must be proven end-to-end.

### Current state (from last workflow run)

- 31 passed, 6 failed, 51 skipped (out of 88 workflow scenarios)
- The 6 failures were addressed by Developer (dev2qa #7: modal border-radius, chat alignment, children list) but have not been re-verified
- The 51 skipped tests have not been investigated

### Action required

**QA**: Produce a full audit of the 51 skipped workflow tests. For each one, report:
1. Which feature file and scenario name
2. Why it is currently skipped (missing step definition, test infrastructure gap, known bug, dependency on another failing test, or other reason)
3. What is needed to unskip it (code fix, test fix, environment setup, or nothing -- just remove the skip)

**Developer + QA**: After the audit, coordinate to fix every blocker. The Developer implements missing backend/frontend functionality; QA fixes test infrastructure issues. Use the qa2dev and dev2qa channels.

**Developer**: If any of the 51 tests are skipped because application functionality is missing or broken, that functionality must be implemented or fixed. This is not optional.

### Success criteria

The workflow suite run must show: **all scenarios passed, zero skipped, zero failed.** Combined with the fast suite (93/93), that means every E2E scenario in the project is green.

### Suggested sequence

1. QA runs the audit (activate `/hats:qa`)
2. QA posts findings to qa2dev
3. Developer fixes blockers (activate `/hats:developer`)
4. QA re-runs and verifies (activate `/hats:qa`)
5. Repeat until all green

This is the gate for completing part one of the project. Nothing else takes priority until this is done.

---

## [6] 2026-03-06T14:00 -- Manager

Re: MAJOR UPDATE — Feature specs overhauled, composition model changed, glossary introduced, clean slate directive

### Summary

The feature specs have been significantly reworked. The composition model has changed. A project glossary now defines all shared terms. There are no users yet — we have full freedom to delete data, drop tables, and refactor without backward compatibility concerns.

### 1. Glossary — use these terms everywhere

A glossary has been written at `.hats/manager/glossary.md` (needs to be moved to `.hats/shared/glossary.md`). All roles must use these terms consistently in code, tests, specs, and docs. Key terms:

- **Design System** — a named collection of Figma files (created by user)
- **Component Set** / **Component** / **Variant** — mirror Figma's structure, imported as-is
- **Vector** — vector-only component displayed as SVG (was previously called "icon" in some places)
- **Slot** — a named placeholder inside a component for child components. **A component can have multiple slots, each with its own allowed children list.** This is a model change.
- **Allowed Children** — per-slot, not per-component. Detected from Figma Slots preferred values (or INSTANCE_SWAP — both are valid ways to define slots in Figma). Figma is flexible; we are strict.

### 2. Composition model change: slots are now per-component, allowed children are per-slot

**Old model:** a component set has one flat `allowed_children` array.

**New model:** a component set has zero or more **named slots**, each slot has its own **allowed children** list.

Example:
```
PageLayout (root)
  └── Slot "header"    → allowed: [Title, Breadcrumb]
  └── Slot "content"   → allowed: [Card, Text, Image]
  └── Slot "actions"   → allowed: [Button, Link]
```

**CTO**: Design the new data model. The current `allowed_children` column on ComponentSet needs to become a slots structure. Investigate the Figma Slots REST API response — what data do we get for slots? Do slots have names? How do preferred values map?

**Developer**: Refactor the importer, React factory, and AI schema generator to support multiple named slots per component. Update the database schema. **Delete old code and old data freely — we have no users. No backward compatibility needed. No legacy migrations.**

### 3. Feature specs — what changed

- **All 17 feature files rewritten** to human-language behavioral descriptions. No API paths, HTTP codes, CSS pixels, or implementation details.
- **14-ai-task-pipeline.feature deleted** — internal pipeline, already covered by 05-design-generation
- **Onboarding Step 4 removed** — no UI for editing root/allowed_children (comes from Figma only)
- **Custom components root/children scenario removed** — root/children come from Figma only
- **Tags simplified** — only `@happy-path` exists (7 scenarios across 4 files tracing the core user journey: sign-in → import → generate → improve). All other tags (`@critical`, `@edge-case`, `@error-handling`) removed. Dev focuses on happy path first.
- **Import flow rewritten** (03-figma-import): user clicks "New design system" → adds Figma URLs → clicks "import" → sees progress → reviews result with success/errors
- **"Icon" renamed to "Vector"** throughout

### 4. Clean slate directive

**We have no users.** This means:

- Drop and recreate database tables freely
- Delete old code, old migrations, old fixtures
- No backward-compatibility shims, no feature flags, no deprecation warnings
- Rename columns, restructure models, rewrite services from scratch if needed
- The only constraint is: make the specs pass

### Action required

**CTO** (`/hats:cto`):
- Move `glossary.md` from `.hats/manager/` to `.hats/shared/`
- Design the new slots data model
- Investigate Figma Slots REST API response
- Update `.hats/shared/stack.md` with new conventions

**Developer** (`/hats:developer`):
- Read all updated feature files — they are the source of truth
- Refactor importer + React factory + AI schema for multi-slot model
- Clean up old code (delete, don't deprecate)
- Rename "icon" to "vector" in code

**QA** (`/hats:qa`):
- Regenerate E2E test scenarios from the updated specs
- Remove tests for onboarding Step 4, root/children editing UI
- Update "icon" references to "vector"

**Designer** (`/hats:designer`):
- Update onboarding wizard design (4 steps, no "Organize" step)
- Update component detail design to show multiple named slots instead of flat allowed_children

---

## [5] 2026-03-06T10:00 -- Manager

Re: Feature specs rewritten + Figma Slots support + root/children editing removed

### What changed

1. **All 18 feature files rewritten** to use human-language behavioral descriptions. Removed all API paths, HTTP status codes, CSS pixel values, implementation details (jobs, pipelines, database models), and renderer internals. Every scenario now reads as a user story.

2. **Figma Slots added to import spec** (03-figma-import.feature). Slots are the primary mechanism for detecting component children. Preferred values on slots become allowed_children. INSTANCE_SWAP remains as legacy fallback. @slot convention removed (deprecated).

3. **Onboarding Step 4 removed** (11-onboarding-wizard.feature). The "Organize components" step that let users toggle is_root and edit allowed_children is gone. These values come exclusively from Figma (via Slots or #root convention). Wizard is now 4 steps: Name → Add Library → Configure AI → Create Project.

4. **CTO action needed**: Investigate Figma's new Slots REST API response. Create a test file with Slots enabled and inspect the raw API data. We need to know if slots appear as a new property type or still come through as INSTANCE_SWAP. Update the importer accordingly.

5. **QA action needed**: All E2E tests that reference the old onboarding Step 4 or root/children editing UI need to be updated or removed. Feature specs are the source of truth — regenerate test scenarios from the new specs.

6. **Designer action needed**: Update the onboarding wizard design to reflect 4 steps (remove the "Organize" step).

---

## [7] 2026-03-06T15:00 -- Manager

Re: Terminology cleanup complete + 17-image-search deleted

### 1. Terminology sweep complete

All "library/libraries" references in feature files have been replaced with the correct user-facing terms per the glossary:

- "Libraries step" → "Figma Files step" (onboarding wizard)
- "selects a library" → "selects a Figma file"
- "added to the library" → "added to the design system" (custom components)
- "libraries page" → "Figma files page" (component browser)
- All other instances fixed across 09, 11, 13, 08

### 2. 17-image-search.feature deleted

Image search is not a user feature — it's internal AI pipeline logic. The AI generates text descriptions of images it needs, and the backend converts those to actual images via Yandex Search. This is an implementation detail that belongs in the CTO's architecture docs or the developer's task list, not in user-facing feature specs.

**CTO/Developer**: If you need to document the image search pipeline, do it in `.hats/shared/stack.md` or similar — it's part of the AI generation internals, not a user-visible feature.

### 4. CTO: move shared files

Move these from `.hats/manager/` to `.hats/shared/` (Manager role can't write there):
- `glossary.md` — project terminology (from message #6)
- `test-figma-files.md` — describes the 3 real Figma files used in tests, their components, and what each file is for

### 3. 18-ui-layout-and-design-system.feature was deleted (previous message)

Entirely design descriptions — belongs in `.hats/designer/`, not feature specs.

### Current feature file count: 15 files (was 18)

Deleted: 14 (ai-task-pipeline), 17 (image-search), 18 (ui-layout)

---

## 2 2026-03-03T16:00 -- Manager

Re: Sprint 2 -- fix 3 remaining bugs from QA validation

QA's E2E run (25 passed, 6 failed, 57 blocked) has been analyzed. All 6 failures trace back to 3 root causes. Here is what needs to happen.

### For Developer (2 bugs)

**Bug 1 (CRITICAL): Preview iframe never appears after design generation -- blocks 29 scenarios**

The investigation shows:
- `DesignView.vue` `fetchDesign()` only sets `currentIterationId` when the iteration already has `jsx` content
- When a design is first generated, the iteration is created with no `jsx` yet
- The AI job (`AiRequestJob`) later sets `iteration.jsx`, then `design.status` changes to `ready`
- There IS polling in DesignView.vue (triggered by `design.status === 'generating'`) but something is preventing the Preview from rendering once generation completes
- Also: `previewRenderer` computed falls through to `design.design_system_id` which does NOT exist on the Design model -- designs link to figma_files via a junction table

Key files:
- `developer/app/src/views/DesignView.vue` lines ~141-157 (`previewRenderer` computed) and ~183-199 (`fetchDesign`)
- `developer/app/src/components/Preview.vue` (understand `v-if` condition for iframe)
- `developer/api/app/jobs/ai_request_job.rb` lines ~32-35 (jsx + status update)

Fix: Make sure that after AI generation completes and polling picks up the updated iteration, `currentIterationId` is set and the Preview iframe becomes visible. Investigate whether `design.design_system_id` fallback is causing "about:blank" and whether Preview hides on "about:blank" src.

**Bug 2: Library detail page has no identifiable heading element -- blocks 9 scenarios**

`LibraryDetailView.vue` renders the library name as a plain `<div>{{ library.name }}</div>` with no class attribute and no semantic heading element. The QA test (and any reasonable selector) cannot find it.

Fix: In `LibraryDetailView.vue` (the `<div v-if="library">{{ library.name }}</div>` in the header slot), add `class="LibraryDetail__name"` and/or change it to an `<h2>` element.

### For QA (1 fix)

**Bug 3: DS modal import timeout too short -- 300s vs actual ~9 minutes**

In the DS modal test, the step waiting for `.DesignSystemModal__browser` uses a 300s (5-minute) timeout, but Figma imports routinely take 8-10 minutes. Increase this to 600s (10 minutes).

Key file: `qa/steps/modal-ui.steps.js` -- find the timeout for `.DesignSystemModal__browser` visibility and increase it.

### Priority

1. Developer fixes Bug 1 (preview iframe) -- the single biggest unblock (29 scenarios)
2. Developer fixes Bug 2 (library detail heading) -- quick, unblocks 9 scenarios
3. QA fixes Bug 3 (modal timeout) -- low effort, unblocks 14 DS modal scenarios

---

## [9] 2026-04-29T17:55 -- Manager

Re: Added 4 INSTANCE size-override scenarios to `03-figma-import.feature`

Tracks Dev #23 in `dev2qa.md`. Validator (`api/app/services/figma/component_validator.rb#find_resized_instances`, already merged in `8b204f6`) now only flags an INSTANCE's bbox mismatch on a **FIXED** axis. **FILL** (parent-driven `flex-grow: 1`) and **HUG** (`fit-content`) axes are expected to differ from the source variant's bbox and are no longer warnings.

### New scenarios — under "Instance size-override warnings" section in `03-figma-import.feature`

1. **FIXED-axis override → warning** (positive). Width differs by >1px on a FIXED-sized axis → warning identifies the width axis.
2. **FILL bbox mismatch → no warning** (negative). Parent-driven width differs from source → no size-override warning.
3. **HUG bbox mismatch → no warning** (negative). Content-hugging height differs from source → no size-override warning.
4. **Mixed sizing** (one of each). FILL horizontal mismatched + FIXED vertical mismatched → warning fires only on the height axis.

### Scope decisions I made

- **No spec for `layoutSizing*` missing/null.** Dev #23 noted the code treats nil as FIXED. I'm leaving that as implementation-default fallback rather than user-visible behaviour. If a real Figma file in the wild stops behaving as expected, we can revisit.
- **Wording in spec is `FIXED-axis size override`** to match the new warning string. The previous "manually resized" phrasing is gone — any test still asserting on it will fail until updated.
- Scenarios use FIGMA_FILE-level Givens (no fixture references). QA decides how to construct the fixture.

### What QA needs to do (from Dev #23)

- Build (or extend `#flexgrow`) a fixture variant + INSTANCE pair with the four `layoutSizing*` permutations.
- Map step defs for `INSTANCE has FIXED|FILL|HUG horizontal/vertical sizing` and the new "validation warning about a FIXED-axis size override on the INSTANCE / identifies the <axis> axis / does not mention the <axis> axis" assertions.
- Drop or rewrite any test currently asserting the old `manually resized` substring.

### Next role

`/hats:qa` to write the tests against these scenarios.

---
