# Manager to Team

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
- Also: `previewRenderer` computed falls through to `design.design_system_id` which does NOT exist on the Design model -- designs link to component_libraries via a junction table

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
