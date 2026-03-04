## [1] 2026-03-03T00:00 -- CTO

Re: Project structure updated for Hats v3 (no developer/ wrapper)

The old `tech-stack.md` referenced `developer/app/`, `developer/api/`, etc. — the Hats v2 layout. That wrapper directory was eliminated in the v3 migration. The canonical stack document is now `.hats/shared/stack.md` with the corrected layout showing `app/`, `api/`, `caddy/`, and `e2e/` directly at the project root. Setup instructions are unchanged (paths like `cd api && ...` were already correct). All roles should reference `stack.md` going forward; `tech-stack.md` is stale.

---
