## [6] 2026-03-06T17:00 -- CTO

Re: Unimplemented endpoints — Developer action required

**For Developer.**

The following endpoints are specified in the Manager's feature specs but do not yet exist in `api/config/routes.rb`. They need to be implemented.

### DesignSystem CRUD (04-design-system-management.feature)

| Method | Path | Notes |
|--------|------|-------|
| GET | /api/design-systems/:id | Show design system with its FigmaFiles |
| PATCH | /api/design-systems/:id | Update name and/or linked FigmaFiles |
| DELETE | /api/design-systems/:id | Delete design system |
| POST | /api/design-systems/:id/figma-files | Add a FigmaFile to an existing design system |
| DELETE | /api/design-systems/:id/figma-files/:figma_file_id | Remove a FigmaFile from a design system |

Currently only `index` and `create` are implemented (`resources :design_systems, only: [:index, :create]`).

### Iteration reset (06-design-improvement.feature)

| Method | Path | Notes |
|--------|------|-------|
| POST | /api/designs/:id/reset | Revert design to previous iteration |

### POST /api/designs/:id/improve — request body clarification

The spec requires the full chat history to be included in the improve request body, not just the new message. Verify the controller accepts and passes the full history to the AI pipeline.

---

## [5] 2026-03-06T16:30 -- CTO

Re: CRITICAL — Procfile still uses Hats v2 paths, must be updated before any deployment

**For Developer.**

The `Procfile` at the project root was never updated when the project migrated from Hats v2 to v3. All three process definitions reference `developer/api` which no longer exists. The file currently reads:

```
web: cd developer/api && bin/rails server -p $PORT -b 0.0.0.0
worker: cd developer/api && bin/jobs
release: cd developer/api && bin/rails db:migrate
```

In the v3 layout, code lives directly at the project root. The correct paths are `cd api && ...`. Please update all three lines accordingly. This is the only change needed — the commands themselves (`bin/rails server`, `bin/jobs`, `bin/rails db:migrate`) are correct.

---

## [1] 2026-03-03T00:00 -- CTO

Re: Project structure updated for Hats v3 (no developer/ wrapper)

The old `tech-stack.md` referenced `developer/app/`, `developer/api/`, etc. — the Hats v2 layout. That wrapper directory was eliminated in the v3 migration. The canonical stack document is now `.hats/shared/stack.md` with the corrected layout showing `app/`, `api/`, `caddy/`, and `e2e/` directly at the project root. Setup instructions are unchanged (paths like `cd api && ...` were already correct). All roles should reference `stack.md` going forward; `tech-stack.md` is stale.

---

## [2] 2026-03-04T12:00 -- CTO

Re: Comprehensive stack documentation update -- stack.md, setup.md, api.md

Reviewed all 18 feature specs and 13 designer files. Updated and expanded the technology documentation:

**stack.md** -- Major update:
- Added design tokens section (all CSS custom properties from the designer's global design system: colors, spacing, border radius, z-index layers)
- Added key domain relationships diagram
- Added Caddy reverse proxy details
- Expanded conventions with frontend design constraints (desktop-only min 1200x600, no page scroll, lowercase labels, font stack)
- Expanded backend conventions (access patterns, business logic location)
- Added renderer endpoint details and task API auth
- Pinned Ruby 3.3.9 and Rails 8.0.2 versions

**setup.md** -- New file:
- Prerequisites (Ruby, Node, PostgreSQL, Caddy)
- Step-by-step install instructions
- Environment variable configuration for both api/ and app/
- Database management commands
- E2E test requirements and notes (Figma token, timeouts, auth mocking)
- Caddy/HTTPS local development notes

**api.md** -- New file:
- Complete endpoint catalog (40+ endpoints across all controllers)
- Auth requirements per endpoint (JWT vs TASKS_TOKEN vs none)
- Response format conventions
- Design status flow (draft -> generating -> ready | error)
- Component library sync flow (pending -> discovering -> importing -> converting -> comparing -> ready | error)
- Renderer postMessage communication protocol

**No stack changes.** The technology choices remain the same -- this update adds documentation depth for the 18 features, not new dependencies.

**tech-stack.md** is officially superseded by stack.md. It remains in `.hats/shared/` but should not be referenced.

---

## [4] 2026-03-06T16:00 -- CTO

Re: Slots data model designed, stack.md updated, terminology standardized

### 1. New slots data model (replaces flat allowed_children)

**Old model**: `component_sets.allowed_children` and `components.allowed_children` — flat JSONB array of component name strings.

**New model**: `component_sets.slots` and `components.slots` — JSONB array of named slot objects:

```json
[
  { "name": "content", "allowed_children": ["Title", "Button"] },
  { "name": "actions", "allowed_children": ["Button", "Link"] }
]
```

**DB migration required**: Drop `allowed_children` column from both `component_sets` and `components`. Add `slots jsonb default '[]'` to both tables. No backward compatibility needed — no users exist. Developer must write this migration.

### 2. Figma Slots API investigation

The Figma REST API exposes slots via a `slots` array on component nodes (alongside `componentPropertyDefinitions`). Each slot has a `name` and `preferredValues` array. The importer should:

1. Check `node["slots"]` first (native Figma Slots)
2. Fall back to scanning `componentPropertyDefinitions` for `INSTANCE_SWAP` entries (legacy)

Both paths produce the same `slots` array structure in our DB. Details and example response shape documented in `stack.md` under "Slots Data Model".

### 3. stack.md changes

- Added "Slots Data Model" section with full DB column spec, JSON structure, and Figma API response shape
- Updated "Key Domain Relationships" diagram to show `slots` on component sets and components
- Updated "Design Generation Flow" steps 1-4 to use slots language
- Updated "Figma Component Authoring Conventions" section: Figma Slots is now primary, INSTANCE_SWAP is fallback
- Updated "External Services": Yandex Images now documented as internal pipeline only (not user feature)
- Added "Terminology" section referencing glossary.md
- Updated "Known Issues": added DB migration pending note

### 4. File moves blocked by permissions

`glossary.md` and `test-figma-files.md` are in `.hats/manager/` but should be in `.hats/shared/`. CTO role cannot write those files (restricted to stack.md, setup.md, api.md, cto2team.md). **Manager needs to copy these two files to `.hats/shared/`.**

### Action required by Developer

- Write migration: remove `allowed_children` from `component_sets` and `components`, add `slots jsonb default '[]'`
- Refactor `Figma::Importer` to populate `slots` instead of `allowed_children`
- Refactor `DesignGenerator#build_schema` to use multi-slot structure
- Refactor `JsonToJsx` / `ReactFactory` to pass named slot content to correct `props.*` positions
- Rename all "icon" references to "vector" in code

### Action required by QA

- Update E2E tests for the new composition model (slots, not allowed_children)
- Rename "icon" to "vector" in step definitions and fixtures

### Action required by Manager

- Move `.hats/manager/glossary.md` to `.hats/shared/glossary.md`
- Move `.hats/manager/test-figma-files.md` to `.hats/shared/test-figma-files.md`

### 5. Project structure validation — discrepancies fixed in stack.md

Validated the actual filesystem against stack.md. All discrepancies are now corrected. Summary of what was wrong:

- `e2e/` was documented as having `features/`, `steps/`, `fixtures/` subdirs. Reality: `e2e/` only contains `node_modules/` and package files. The Gherkin test source lives in `.hats/qa/`. Stack.md now says so explicitly.
- `api/app/services/` was missing: `exports/react_project_builder.rb`, `json_to_jsx.rb`, `yandex_images.rb`, `auth0_service.rb`, and several figma/ files (`JsxCompiler`, `ComponentResolver`, `SingleComponentImporter`, `HtmlConverter`).
- `api/app/jobs/` was missing `VisualDiffJob`.
- Controller concerns (`renderable.rb`) and model concerns (`component_naming.rb`) were not documented.
- Full controller and component lists were not documented.
- `app/src/test-support/mock-auth0.js` and `app/src/__tests__/setup.js` were not documented.
- `caddy/certs/` was not documented.
- Auth mock condition was wrong — mock loads in `DEV` mode too, not only `VITE_E2E_TEST=true`.
- Makefile targets `clean_dev`, `test-render`, `test-render-fresh`, `setup`, `setup-e2e` were missing.
- `Procfile` was not documented at all.

**CRITICAL BUG for Developer**: `Procfile` at the project root still contains Hats v2 paths (`cd developer/api && ...`). All three process definitions (web, worker, release) are broken. Developer must update `Procfile` to use `cd api && ...`.

---

## [3] 2026-03-04T17:00 -- CTO

Re: Documentation consolidation -- design flow, Figma conventions, testing guide into .hats/shared/

Migrated content from the bloated CLAUDE.md (490 lines) into the existing `.hats/shared/` documentation files:

**stack.md** -- Added three new sections at the end:
- Design Generation Flow (8-step pipeline with key files table). Fixed Step 2: removed incorrect "read-only" claim about is_root/allowed_children -- they are auto-set from Figma conventions but remain editable in the UI.
- Figma Component Authoring Conventions (INSTANCE_SWAP + preferredValues, #root, #list, TEXT properties, Page component example). Merged the two duplicate sections from CLAUDE.md into one clean section.
- Known Issues (ChatMessage model, art director disabled).

**setup.md** -- Added three new sections:
- Test Suite Organization (primary .hats/qa/ suite with 19 features/134 scenarios, dev tests, legacy e2e/ note)
- Writing Strong Tests (assertion rules for AI agents writing tests)
- Fixed FIGMA_ACCESS_TOKEN -> FIGMA_TOKEN (the actual env var name used in the codebase)

**CLAUDE.md** -- Could not rewrite (CTO role is restricted to .hats/ directory). Recommend the Manager slim CLAUDE.md to ~30 lines pointing to .hats/shared/ docs. The implementation plan (Sessions 1-8), E2E test catalog, and all duplicated content should be removed.

**Recommended cleanup** (for Manager): Remove the legacy `e2e/` directory -- it is fully superseded by `.hats/qa/`.

---
