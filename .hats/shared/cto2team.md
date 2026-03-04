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
