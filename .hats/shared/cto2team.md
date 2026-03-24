## [15] 2026-03-24T12:00 -- CTO

Re: Testing responsibilities — Developer owns TDD, QA owns user-facing verification

### Two levels of testing, two owners

**Developer = TDD (unit + integration specs)**

The Developer writes and maintains RSpec tests. TDD is the religion: write the test first, watch it fail (red), write the code, watch it pass (green). Every commit from the Developer MUST leave the test suite green. If a change breaks a test, the Developer fixes it before pushing — not later, not in a follow-up.

What Developer tests cover:
- Model behavior, validations, associations
- Service logic (Resolver, Emitter, Importer, etc.)
- Controller/request specs (API contracts)
- Pipeline integration (`figma2react_test.rake`)
- Any internal logic that doesn't require a browser

Developer tests live in `api/spec/`. They run with `make test-api` and `make test-app` (Vitest for Vue components). They are fast, deterministic, and run in CI.

The Developer NEVER ships code without running tests. "It works" without test proof = not done.

**QA = User-facing verification (Playwright E2E)**

QA writes and maintains Playwright tests. QA tests verify the app works **from the user's perspective** — clicking buttons, filling forms, seeing results in the browser. QA does NOT test internal logic, service methods, or database behavior. QA tests that the whole stack works together through the UI.

What QA tests cover:
- Authentication flow in browser
- Figma import triggered from UI, progress visible
- Design generation via prompt, preview renders
- Component browser navigation, props interaction
- Export buttons produce files
- Chat/improve flow works end-to-end

QA tests live in `.hats/qa/`. They run with `cd .hats/qa && bash run-tests.sh fast|workflow|render`.

### Why two levels

Developer tests catch logic bugs fast — wrong resolution, bad JSX, broken SQL. They run in seconds and pinpoint the exact method that broke.

QA tests catch integration bugs that unit tests miss — a controller returns data but the Vue component doesn't render it, an API change silently breaks the frontend, a race condition only appears when real jobs run.

Neither level replaces the other. A green RSpec suite doesn't mean the app works for users. A green Playwright suite doesn't mean the internals are correct.

### Rules

1. **Developer**: every PR must have green `make test-api && make test-app`. If your change adds behavior, add a spec. If your change breaks a spec, fix the spec (or fix your code). Never comment out or skip a test to make CI green.
2. **QA**: don't test implementation details. Don't check database state, don't assert on internal CSS classes, don't verify service method return values. Test what the user sees and does.
3. **Developer → QA handoff**: after Developer ships, Developer posts to `dev2qa.md` what changed so QA knows what to verify. QA runs their suite and reports in `qa2dev.md` if anything is broken.
4. **No orphaned changes**: if Developer changes API response shape, Developer updates the request spec. If that change breaks a QA test, QA updates the step definition. Each side owns their layer.

---

## [14] 2026-03-17T19:00 -- CTO

Re: Autonomous agent workflow — self-verify, don't declare victory, don't stop early

### Problem

Agents write code and say "done" without verifying it works. The human then has to manually check, find it broken, and ask the agent to fix it. This defeats the purpose of autonomous agents. The human cannot sit and babysit — agents must do their best to ship working code without supervision.

### Principles

#### 1. Don't ask what you can check yourself

Before asking the human a question, ask yourself: can I answer this by reading code, running a command, or searching the codebase? If yes, do that instead. Examples of questions you should never ask:

- "Does this file exist?" → use Glob
- "What's the current schema?" → read schema.rb
- "Is the API key configured?" → read .env or check ENV in a test
- "Did the migration run?" → check schema.rb or run db:migrate:status
- "What does this component look like?" → read the code

The human's time is the scarcest resource. Only ask when you genuinely cannot determine the answer yourself.

#### 2. Self-verify end-to-end — never declare "done" without proof

Writing code is half the job. The other half is proving it works. After implementing a feature or fix:

1. **Run the relevant tests** — not just fast tests, the full suite that covers your change
2. **If tests pass, check the actual behavior** — does the API return what the spec says? Does the UI render? Does the Figma plugin work?
3. **If tests fail, fix them** — don't report failures and stop. Read the error, diagnose, fix, re-run
4. **If no tests exist for your change, write them** — untested code is unfinished code

"Done" means: code written + tests pass + behavior verified. Not just "code written."

#### 3. Never stop at "fast tests passed"

Fast tests cover basic request/response. They don't cover:
- Figma import pipeline end-to-end
- AI generation with real components
- Preview rendering with real JSX
- Plugin export with real tree data

If your change touches any of these, run the workflow tests too. "93/93 fast passed" is not a finish line — it's a checkpoint.

#### 4. Never stop at "API key needed" or "environment issue"

All API keys (Figma, OpenAI, Yandex) are configured in both dev and test environments. If a test fails with "key not found" or "unauthorized", the bug is in your code (wrong env var name, wrong config path, missing initialization), not in the environment. Investigate, don't punt.

#### 5. Maximize auto-approved tool usage

These tools don't need human approval: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Agent`. Use them aggressively:

- Read test output with `Read`, not by re-running
- Search for patterns with `Grep`, not by asking
- Fix code with `Edit`, not by describing what to change
- Use `Agent` subagents for parallel research

When you do need `Bash`, batch everything into one command (see decision [13]). The goal: the human approves 2-3 Bash calls per task, not 15.

#### 6. Iterate until it works, not until you've tried once

The workflow is:
```
write code → run tests → read failures → fix → run tests → read failures → fix → ...
```

Not:
```
write code → run tests → report failures → stop
```

If something breaks, you have all the tools to diagnose and fix it. Keep going. Only stop and ask the human when you've genuinely exhausted your options — you've tried multiple approaches and none work, or you need a design decision that isn't covered by the specs.

#### 7. When in doubt, do more rather than less

If you're unsure whether to run one more test, check one more edge case, or verify one more thing — do it. The cost of being thorough is a few extra minutes of compute. The cost of shipping broken code is the human's time and trust.

### For all agents

This applies to Developer, QA, and any agent that writes or tests code. The human is not a debugger, not a test runner, and not a search engine. You are.

---

## [13] 2026-03-16T17:00 -- CTO

Re: Autonomous Developer workflow — minimize human approvals

### Problem

Every `Bash` tool call requires the session runner to click approve. This breaks flow and makes the human a bottleneck. The Developer agent should be able to write code, test it, read results, fix issues, and iterate — with the human only approving a small number of predictable commands.

### Principle: front-load tooling, batch execution

The Developer agent has **auto-approved tools**: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Agent`. These cover ~80% of development work (reading code, writing code, searching). The remaining 20% — running tests, building, migrating — requires `Bash`.

The strategy:
1. **Write all code changes first** using `Write`/`Edit` (no approval needed)
2. **Run a single compound Bash command** to validate everything at once
3. **Read output** to diagnose failures (auto-approved)
4. **Fix with Edit** (auto-approved)
5. **Run again** (one more Bash approval)

### Rules for Developer

#### 1. Batch Bash commands with `&&`

Never run `cd api && bundle exec rspec spec/models/foo_spec.rb` as one call and then `cd api && bundle exec rspec spec/requests/bar_spec.rb` as another. Chain them:

```bash
cd api && bundle exec rspec spec/models/foo_spec.rb spec/requests/bar_spec.rb
```

Or use Make targets:

```bash
make test-api
```

#### 2. Use Makefile targets, not raw commands

The Makefile already has `test-api`, `test-app`, `test`, `clean_dev`. Use these instead of typing raw commands. If a common operation doesn't have a target, **create one first** (via `Edit` on the Makefile — no Bash needed), then run it.

#### 3. Create helper scripts for multi-step operations

If a task requires a sequence of Bash commands (e.g., migrate + seed + test), write a shell script first using `Write` (auto-approved), then run it with one Bash call:

```bash
bash tmp/do-migration.sh
```

The script is disposable — put it in `tmp/` or `bin/dev/`. One approval instead of five.

#### 4. Makefile as the single command surface

All repeatable operations must have a Makefile target. The Developer should add targets as needed. Current targets cover the basics; add more for:

- Running a single spec file: `make spec FILE=spec/requests/foo_spec.rb`
- Running migrations: `make migrate`
- Rebuilding Figma plugin: `make build-plugin`
- Linting: `make lint`

#### 5. Read test output, don't re-run blindly

After a test run, read the output carefully. Fix all failures in one pass using `Edit`, then run tests once more. Don't ping-pong between "run → fail → fix one thing → run → fail → fix another thing". That's N approvals instead of 2.

#### 6. Use parallel Bash calls when independent

The `Bash` tool supports multiple calls in one message. If you need to run API tests AND frontend tests, fire both in parallel — one approval prompt covers both.

### New Makefile targets to add

```makefile
# Run a specific RSpec file or pattern
# Usage: make spec FILE=spec/requests/designs_spec.rb
spec:
	cd api && bundle exec rspec $(FILE)

# Run Rails migration
migrate:
	cd api && bin/rails db:migrate

# Build Figma plugin bundles
build-plugin:
	cd figma-plugin && npm run build

# Run a one-off Rails runner script
# Usage: make runner FILE=tmp/debug.rb
runner:
	cd api && bin/rails runner $(FILE)

# Run a quick sanity check: migrate + test
check:
	cd api && bin/rails db:migrate && bundle exec rspec && cd ../app && npm test
```

### For Developer

1. Add the new Makefile targets above
2. When working on a task: write ALL code changes first, then run `make check` or the relevant `make spec FILE=...` as a single validation step
3. If you need a custom multi-step operation, write it to `tmp/` as a script, run it once
4. Never run more than 3 Bash commands for a single code change cycle (write → validate → fix → re-validate)

### For session runner

With this approach, a typical development cycle looks like:

1. Agent reads code (auto) → writes changes (auto) → **runs `make check`** (approve once)
2. Agent reads test output (auto) → fixes issues (auto) → **runs `make check`** (approve once)
3. Done. Two approvals per iteration.

The session runner's job is to approve Make targets and review the final result, not to babysit individual commands.

---

## [12] 2026-03-16T16:00 -- CTO

Re: Extract `figma-dev-loop/` — standalone service for Claude ↔ Figma plugin automation

### What this is

A tight feedback loop: Claude edits plugin code → builds → triggers render → plugin executes in Figma's sandbox → reports result back → Claude reads logs and iterates. No human interaction once the plugin's "Start Dev Loop" button is pressed.

### Current state (embedded in Rails)

The dev loop currently lives across three places:
- `DevPluginController` (Rails) — 5 endpoints using class variables (`@@trigger`, `@@result`) as in-memory queue
- `figma-plugin/src/ui.html` — polling logic, `executeDevRun` flow
- `figma-plugin/src/dev-entry.ts` + `tree-renderer.ts` — eval'd code that runs in Figma sandbox

The Rails controller is a bad fit: class variables don't survive Puma restarts, they're not thread-safe, and the dev loop has zero dependency on the Rails app's models or auth. The only thing it needs from Rails is the `export_figma` endpoint to get tree data — and the plugin fetches that directly by URL, not through the dev loop server.

### Decision: Extract to `figma-dev-loop/` at project root

A standalone Node.js service. No framework — just a plain HTTP server. It does three things:

1. **Serve the dev bundle** — reads `figma-plugin/dist/dev-bundle.js` from disk
2. **Command queue** — Claude posts commands, plugin polls for them
3. **Result store** — plugin posts results, Claude reads them

#### Project structure

```
figma-dev-loop/
  server.js          # Single-file HTTP server (~100 lines)
  package.json       # No dependencies (or just cors if needed)
```

No TypeScript, no framework, no build step. This is a relay, not a product.

#### API endpoints (all on port 4000)

| Method | Path | Caller | Description |
|--------|------|--------|-------------|
| GET | /bundle | Plugin | Serve `../figma-plugin/dist/dev-bundle.js` |
| POST | /trigger | Claude | Queue a command `{ action, code, tree? }` |
| GET | /poll | Plugin | Get next pending command (clears it) |
| POST | /result | Plugin | Post render result `{ status, error?, logs }` |
| GET | /result | Claude | Read latest result |
| GET | /health | Either | `{ status: "ok", pending: bool }` |

No `/api` prefix — this isn't the main app. Short paths for a dev tool.

#### Command types

The current system only has one command: `run` (fetch bundle → eval → fetch tree → render). But we should support two more for Claude to be effective:

| Command | What it does |
|---------|-------------|
| `run` | Full cycle: eval fresh bundle + render tree from a share code |
| `eval` | Eval arbitrary JS in the Figma sandbox (no render). For testing small snippets. |
| `inspect` | Run a JS expression and return the result. For reading Figma state (node tree, properties, etc.) |

The `eval` and `inspect` commands let Claude debug without a full render cycle. Critical for the "try code, check what works" workflow.

#### Plugin-side changes

The plugin UI's dev loop code needs to point to `http://localhost:4000` instead of `${DEV_URL}/api/plugin/...`. The `executeDevRun` function needs to handle the new command types.

In `ui.html`, the dev loop URL becomes a constant:
```js
const DEV_LOOP_URL = 'http://localhost:4000';
```

The plugin still fetches tree data from the main Rails app (`DEV_URL/api/iterations/:code/export-figma`). The dev loop server doesn't proxy this — the plugin has direct access.

#### Command flow

```
Claude                    figma-dev-loop (port 4000)           Plugin (Figma)
  │                              │                                │
  │ POST /trigger {action:"run"} │                                │
  │─────────────────────────────>│                                │
  │                              │   GET /poll                    │
  │                              │<───────────────────────────────│
  │                              │   {action:"run", code:"dev-x"} │
  │                              │───────────────────────────────>│
  │                              │                                │
  │                              │                    [fetch bundle from /bundle]
  │                              │                    [eval in sandbox]
  │                              │                    [fetch tree from Rails]
  │                              │                    [render in Figma]
  │                              │                                │
  │                              │   POST /result {status, logs}  │
  │                              │<───────────────────────────────│
  │  GET /result                 │                                │
  │─────────────────────────────>│                                │
  │  {status:"success", logs:[]} │                                │
  │<─────────────────────────────│                                │
```

### Error resilience — the plugin must never die

This is the most critical design principle. If the plugin crashes or hangs, the entire feedback loop is broken and requires human intervention (reopening the plugin in Figma). Every error must be caught and reported, never propagated.

#### 1. Top-level try/catch in the dispatcher

`code.ts` already has this partially. The `__handlePluginMessage` handler must wrap ALL work in try/catch:

```typescript
figma.ui.onmessage = async (msg: any) => {
  try {
    if (msg.type === "dev-eval") {
      try {
        eval(msg.code);
        figma.ui.postMessage({ type: "dev-eval-done" });
      } catch (e: any) {
        figma.ui.postMessage({ type: "dev-eval-error", error: e.message });
      }
      return;
    }
    await (globalThis as any).__handlePluginMessage(msg);
  } catch (e: any) {
    // Last resort — never let an unhandled error kill the plugin
    figma.ui.postMessage({ type: "fatal-error", error: e.message || String(e) });
  }
};
```

#### 2. Eval isolation — bad code must not corrupt global state

The eval'd dev-bundle.ts overwrites `__handlePluginMessage`. If the eval'd code throws during setup (not during execution), the handler is left in a broken state. Fix: wrap the overwrite in a transaction pattern:

```typescript
// In dev-entry.ts — save previous handler before overwriting
const _previousHandler = (globalThis as any).__handlePluginMessage;
try {
  (globalThis as any).__handlePluginMessage = async (msg: any) => {
    // ... new handler code ...
  };
} catch (e) {
  // Restore previous handler if setup fails
  (globalThis as any).__handlePluginMessage = _previousHandler;
  throw e;
}
```

#### 3. Render timeout — the plugin side

The UI's `waitForMessage` already has a timeout (120s for render, 15s for eval). But if the render hangs inside the Figma sandbox (infinite loop in tree-renderer), `waitForMessage` times out and reports an error — good. The plugin stays alive because the hang is in an async function, not a sync infinite loop.

**Sync infinite loops are unrecoverable.** If eval'd code has `while(true){}`, the Figma sandbox freezes. There's no workaround for this in the plugin environment. The dev-entry.ts code must be carefully written to avoid sync loops. The dev loop server should document this as a known limitation.

#### 4. Memory cleanup between runs

Each dev run creates Figma nodes. Over many iterations these accumulate. The plugin should clean up previous dev frames before rendering a new one:

```typescript
// Before creating a new rootFrame, remove previous dev frames
const prevFrames = figma.currentPage.children.filter(
  n => n.type === "FRAME" && n.name.startsWith("[v")
);
for (const f of prevFrames) f.remove();
```

#### 5. Console capture must be restorable

`dev-entry.ts` overwrites `console.log` and `console.warn`. If eval'd multiple times, the overrides stack (wrapping wrappers). The current code already saves `_origLog`/`_origWarn`, but on re-eval those get overwritten with the previous wrapped version. Fix: save originals on first eval only:

```typescript
if (!(globalThis as any).__origConsoleLog) {
  (globalThis as any).__origConsoleLog = console.log;
  (globalThis as any).__origConsoleWarn = console.warn;
}
const _origLog = (globalThis as any).__origConsoleLog;
const _origWarn = (globalThis as any).__origConsoleWarn;
```

### Makefile integration

```makefile
# Start the Figma dev loop relay server
dev-loop:
	cd figma-dev-loop && node server.js
```

### What to remove from Rails

- Delete `DevPluginController`
- Delete the 5 routes in `routes.rb` under `# Dev plugin hot-reload loop`
- Remove the CORS entry for `/api/plugin/*` in `cors.rb`

### What stays in `figma-plugin/`

Everything. The plugin source (`code.ts`, `dev-entry.ts`, `tree-renderer.ts`, `ui.html`, `manifest.json`) stays in `figma-plugin/`. The dev loop server reads the built bundle from `figma-plugin/dist/`. The plugin is not moved.

### For Developer

1. Create `figma-dev-loop/server.js` — plain Node HTTP server on port 4000 with the 6 endpoints above
2. Create `figma-dev-loop/package.json` — no dependencies
3. Update `figma-plugin/src/ui.html` — dev loop URLs point to `http://localhost:4000`
4. Update `figma-plugin/src/dev-entry.ts` — console capture fix (save originals once), handler rollback on eval failure
5. Update `figma-plugin/src/code.ts` — top-level catch-all in dispatcher
6. Add cleanup of previous dev frames before each render
7. Support `eval` and `inspect` command types in the plugin
8. Delete `DevPluginController` and its routes/CORS from Rails
9. Add `dev-loop` target to Makefile
10. Rebuild plugin bundles

### Stack note

`figma-dev-loop/` is a dev-only tool. It does not deploy to Heroku, has no database, and has no auth. It's a local relay between Claude Code (CLI) and the Figma plugin.

---

## [11] 2026-03-16T15:30 -- CTO

Re: URL convention — hyphens everywhere, no underscores in routes

### Decision

All URL paths use **hyphens** (`kebab-case`), never underscores. This applies to resource paths (already done) and member/collection action paths (not yet done).

Rails convention is underscores in route helpers and controller methods — that's fine internally. The URL the user sees must use hyphens.

### Current state

Already correct:
- `/api/figma-files`, `/api/component-sets`, `/api/design-systems`

Need fixing — member actions with underscores:

| Current | New |
|---------|-----|
| `/api/components/:id/figma_json` | `/api/components/:id/figma-json` |
| `/api/components/:id/html_preview` | `/api/components/:id/html-preview` |
| `/api/components/:id/visual_diff` | `/api/components/:id/visual-diff` |
| `/api/components/:id/diff_image` | `/api/components/:id/diff-image` |
| `/api/component-sets/:id/figma_json` | `/api/component-sets/:id/figma-json` |
| `/api/designs/:id/export_image` | `/api/designs/:id/export-image` |
| `/api/designs/:id/export_react` | `/api/designs/:id/export-react` |
| `/api/designs/:id/export_figma` | `/api/designs/:id/export-figma` |
| `/api/iterations/:share_code/export_figma` | `/api/iterations/:share_code/export-figma` |
| `/api/iterations/:share_code/export_react` | `/api/iterations/:share_code/export-react` |
| `/api/images/render` | OK (single word, no change) |
| `/api/plugin/dev_bundle` | `/api/plugin/dev-bundle` |
| `/api/plugin/dev_trigger` | `/api/plugin/dev-trigger` |
| `/api/plugin/dev_poll` | `/api/plugin/dev-poll` |
| `/api/plugin/dev_result` | `/api/plugin/dev-result` |
| `/api/designs/:id/export_image` | `/api/designs/:id/export-image` |

### How to fix in Rails

Use the `:path` option on member routes. Controller method names stay as underscores (Ruby convention). Example:

```ruby
resources :components, only: [:update] do
  get :figma_json, on: :member, path: "figma-json"
  get :html_preview, on: :member, path: "html-preview"
  get :visual_diff, on: :member, path: "visual-diff"
  get :diff_image, on: :member, path: "diff-image"
  get "screenshots/:type", on: :member, action: :screenshot, as: :screenshot
end
```

For standalone routes:
```ruby
get "iterations/:share_code/export-figma", to: "iterations#export_figma", as: :iteration_export_figma
get "iterations/:share_code/export-react", to: "iterations#export_react", as: :iteration_export_react
```

### Frontend changes required

Search the Vue app for any hardcoded API paths containing underscores and update them. Likely in:
- Export actions (`export_figma`, `export_react`, `export_image`)
- Component detail views (`figma_json`, `html_preview`, `visual_diff`, `diff_image`)
- Figma plugin UI (`dev_bundle`, `dev_trigger`, `dev_poll`, `dev_result`)

### For Developer

1. Update `routes.rb` — add `path:` overrides on all underscore member routes
2. Grep the Vue `app/src/` directory for underscore API paths and update
3. Update the Figma plugin `ui.html` URLs (`dev_bundle` → `dev-bundle`, etc.)
4. No controller/method renaming needed — only URL paths change

### For QA

After developer ships, verify no E2E tests break on the renamed URLs. Step definitions that hit API endpoints directly (not through the UI) will need path updates.

### Going forward

Any new endpoint must use hyphens in the URL path. Controller methods remain Ruby snake_case.

---

## [10] 2026-03-16T15:00 -- CTO

Re: Local prod DB for debugging production bugs

### Problem

When a user reports a bug in production, we can't reproduce it locally because dev and prod have different data. We need a safe, repeatable way to pull the prod database down and run the dev server against it.

### Decision: `make prod-db` target + `PROD_DB` env var

#### 1. Pull prod DB — new Makefile target `prod-db`

```makefile
# Pull production database to local for debugging
prod-db:
	@echo "Pulling production database..."
	dropdb --if-exists jan_designer_api_prodcopy
	heroku pg:pull DATABASE_URL jan_designer_api_prodcopy --app design-gpt
	@echo "Done. Run: make dev-prod"
```

This uses `heroku pg:pull` which:
- Creates a local PostgreSQL database (`jan_designer_api_prodcopy`)
- Pulls a full snapshot from the Heroku Postgres add-on
- Works without `pg_dump` file management — one command
- Requires the Heroku CLI and `heroku login`

The local DB name is `jan_designer_api_prodcopy` — deliberately NOT `_development` or `_test` so it cannot be confused with or overwritten by `db:drop`, `clean_dev`, or test setup.

#### 2. Run dev server against prod copy — new Makefile target `dev-prod`

```makefile
# Start dev servers against local prod DB copy
dev-prod:
	@trap 'kill -- -$$; sleep 1; kill -9 -- -$$ 2>/dev/null; exit' INT TERM; \
	cd api && DATABASE_URL=postgres://localhost/jan_designer_api_prodcopy bin/rails server -p 3000 -b 127.0.0.1 & \
	cd app && npm run dev & \
	cd caddy && caddy run --config Caddyfile & \
	wait
```

When `DATABASE_URL` is set, Rails uses it over `database.yml` — this is standard Rails behavior (documented in `database.yml` line 66-77). The dev server connects to the prod copy. Everything else (Vite, Caddy, Auth0) works identically.

#### 3. Safety guarantees

- **Read-only by convention, not enforcement**: The local copy is a regular PostgreSQL database. You can read and write to it. This is intentional — you may need to test a fix against prod data. But `DATABASE_URL` only points to the LOCAL copy, never to the remote Heroku database.
- **No risk of writing to prod**: `heroku pg:pull` creates a one-way local snapshot. Rails connects to `postgres://localhost/...`. There is no connection string to the remote database anywhere in the dev environment.
- **Isolated from dev/test**: The database name `jan_designer_api_prodcopy` is separate from `_development` and `_test`. Running `make clean_dev` or `db:drop` won't touch it (those target `jan_designer_api_development`).
- **Disposable**: `dropdb jan_designer_api_prodcopy` cleans up. The `prod-db` target drops and recreates on each run.

#### 4. No schema migration step needed

`heroku pg:pull` copies the full database including schema. The prod DB is always at the latest migration (the `release` Procfile entry runs `db:migrate` on every deploy). No local `db:migrate` is needed after pulling.

#### 5. Auth note

Prod users authenticate via Auth0 with real RS256 JWTs. When running `dev-prod`, the mock Auth0 plugin in the frontend will still be active (because Vite runs in dev mode). You'll be logged in as the mock user (`auth0|alice123`), but the prod DB may not have that user. Auto-creation via `current_user` in `ApplicationController` will handle it — a new User row is created on first request. This is fine for debugging; you'll see the app with an empty user state but can navigate to any URL.

If you need to impersonate a specific prod user, look up their `auth0_id` in the prod copy and set it in `mock-auth0.js`.

### For Developer

Add two targets to `Makefile`:

```makefile
# Pull production database to local for debugging
prod-db:
	@echo "Pulling production database..."
	dropdb --if-exists jan_designer_api_prodcopy
	heroku pg:pull DATABASE_URL jan_designer_api_prodcopy --app design-gpt
	@echo "Done. Run: make dev-prod"

# Start dev servers against local prod DB copy
dev-prod:
	@trap 'kill -- -$$; sleep 1; kill -9 -- -$$ 2>/dev/null; exit' INT TERM; \
	cd api && DATABASE_URL=postgres://localhost/jan_designer_api_prodcopy bin/rails server -p 3000 -b 127.0.0.1 & \
	cd app && npm run dev & \
	cd caddy && caddy run --config Caddyfile & \
	wait
```

Also add to `setup.md` under a new "Debugging Production Bugs" section:

```
## Debugging Production Bugs

Pull the production database locally and run against it:

    make prod-db      # Pull prod DB snapshot (requires: heroku login)
    make dev-prod     # Start dev servers against prod copy

Access at https://design-gpt.localtest.me as usual. The database is a local copy — safe to read and modify.
```

---

## [9] 2026-03-09T12:00 -- CTO (updated 2026-03-09T13:00)

Re: CRITICAL -- Dev and test databases not properly separated at runtime

### Problem

The `database.yml` correctly defines separate databases (`jan_designer_api_development` for development, `jan_designer_api_test` for test). However, at runtime the E2E tests silently connect to the development database when `make dev` is already running.

### Root cause

All four Playwright configs (`.hats/qa/playwright.config.js`, `playwright.fast.config.js`, `playwright.workflow.config.js`, `playwright.render.config.js`) define a webServer entry that starts Rails on port 3000 with `RAILS_ENV=test E2E_TEST_MODE=true`. They all set `reuseExistingServer: true` for the Rails server.

When a developer has `make dev` running (which starts Rails in `development` mode on port 3000), Playwright detects port 3000 is occupied and **reuses the existing development server** instead of starting a new one in test mode. The `e2e:setup` rake task seeds data into `jan_designer_api_test` (because it runs with `RAILS_ENV=test`), but HTTP requests from the tests hit the dev server which reads from `jan_designer_api_development`. The seeded test data is invisible to the tests, and any writes from tests corrupt the development database.

Additionally, `setup.md` line 99 says E2E tests require "Dev servers running (`make dev`)" -- this instruction actively causes the bug.

### Decision: Two domains, two port sets, one Caddy instance

Dev and test get fully separate domains and backend ports so they can run simultaneously without any interference.

- **Dev**: `https://design-gpt.localtest.me` -> Rails 3000 + Vite 5173
- **Test**: `https://design-gpt-test.localtest.me` -> Rails 3001 + Vite 5174

Both `*.localtest.me` subdomains resolve to `127.0.0.1` via DNS (this is what localtest.me does -- all subdomains resolve to loopback).

**For Developer -- changes required:**

#### 1. `caddy/Caddyfile` -- add a second site block for the test domain

```
design-gpt.localtest.me {
  tls internal

  @api path /api*
  handle @api {
    reverse_proxy 127.0.0.1:3000 {
      header_up Host {host}
      header_up X-Forwarded-Proto https
      header_up X-Forwarded-Host {host}
      header_up X-Forwarded-Port 443
    }
  }

  handle {
    reverse_proxy 127.0.0.1:5173
  }
}

design-gpt-test.localtest.me {
  tls internal

  @api path /api*
  handle @api {
    reverse_proxy 127.0.0.1:3001 {
      header_up Host {host}
      header_up X-Forwarded-Proto https
      header_up X-Forwarded-Host {host}
      header_up X-Forwarded-Port 443
    }
  }

  handle {
    reverse_proxy 127.0.0.1:5174
  }
}
```

Both site blocks live in the same Caddyfile, served by one Caddy process on port 443. The dev block routes to 3000/5173, the test block routes to 3001/5174. No env var templating needed -- plain static config.

#### 2. All four Playwright configs (`.hats/qa/playwright*.config.js`)

**Rails webServer**:
- Command: `cd ../../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails server -p 3001 -b 127.0.0.1`
- `port: 3001`
- `reuseExistingServer: false`

**Vite webServer**:
- Command: `cd ../../app && VITE_E2E_TEST=true npx vite --port 5174`
- `port: 5174`
- `reuseExistingServer: false`

**Caddy webServer**:
- Command stays: `cd ../../caddy && caddy run --config Caddyfile`
- `port: 443`
- `reuseExistingServer: true` (keep as-is -- single Caddy serves both domains; if dev Caddy is already running, tests reuse it and that is correct because the same Caddy routes both domains)

**baseURL**: Change from `https://design-gpt.localtest.me` to `https://design-gpt-test.localtest.me` in all four configs.

#### 3. `app/vite.config.js` -- add test domain to allowedHosts

```js
allowedHosts: [
  "design-gpt.localtest.me",
  "design-gpt-test.localtest.me",
],
```

The test Vite instance runs on port 5174. Caddy sends requests with `Host: design-gpt-test.localtest.me`. Vite must allow that hostname or it will reject the connection.

#### 4. `api/config/environments/test.rb` -- add test domain to hosts

Add inside the `configure` block:

```ruby
config.hosts << "design-gpt-test.localtest.me"
```

Rails test environment currently has NO `config.hosts` entries, which means it accepts all hostnames. This is fine for now -- Rails defaults to allowing all hosts when the list is empty. However, if someone later adds a `config.hosts` entry for another reason, the test domain would break. Adding it explicitly is defensive and cheap. **This is optional but recommended.**

#### 5. CORS -- no change needed

The CORS initializer (`api/config/initializers/cors.rb`) controls cross-origin requests. Since both frontend and API are served through the same Caddy domain (`design-gpt-test.localtest.me`), all requests are same-origin. CORS does not apply to same-origin requests. No change needed.

#### 6. `setup.md` -- fix the E2E prerequisites

Remove the instruction "Dev servers running (`make dev`)" from E2E test prerequisites. Replace with: "Playwright starts its own servers automatically. `make dev` can be running simultaneously -- they use separate ports and domains."

#### 7. `Makefile` -- no changes needed

The `dev` target starts Rails on 3000 and Vite on 5173 (unchanged). The `test-e2e` target runs `db:test:prepare`, `e2e:setup`, then `npx playwright test` -- Playwright starts its own servers on 3001/5174 via webServer config.

### Port and domain allocation

| Service | Dev (`make dev`) | E2E tests (Playwright) |
|---------|-----------------|----------------------|
| Domain  | `design-gpt.localtest.me` | `design-gpt-test.localtest.me` |
| Rails   | 3000            | 3001                 |
| Vite    | 5173            | 5174                 |
| Caddy   | 443 (shared, one instance serves both domains) | (same) |

### Why this approach

- **Full coexistence**: Dev and test run simultaneously without any conflict. Different ports for Rails and Vite, different domains for Caddy routing, single Caddy instance.
- **No env var templating**: The Caddyfile uses plain static config. Two site blocks, no `{env.VAR}` complexity.
- **Same HTTPS topology as production**: Tests go through Caddy with `tls internal`, exercising the same proxy layer. No "skip Caddy in tests" divergence.
- **One Caddy process**: Both site blocks are served by the same Caddy instance on port 443. Starting `make dev` or Playwright first doesn't matter -- whichever starts Caddy first, the other reuses it.
- **Loud failure on misconfiguration**: `reuseExistingServer: false` on Rails and Vite means Playwright will fail fast if port 3001 or 5174 is already taken, rather than silently reusing a wrong server.

---

## [8] 2026-03-07T22:30 -- CTO

Re: API keys policy -- real keys are available for dev and testing

**All external API keys (FIGMA_ACCESS_TOKEN, OPENAI_API_KEY) are configured in the test environment.** Do not assume they are missing. Do not categorize test failures as "environment-dependent" or "needs API key" without actually verifying that the key is absent.

We use real API keys for development and E2E testing. The cost of API calls is acceptable -- we need to test full functionality end-to-end, including Figma import and AI generation. Skipping or writing off test failures as "needs API key" hides real bugs.

**For QA**: When tests fail, investigate the actual error. If a test times out or returns an unexpected response, the root cause is likely a code bug or selector mismatch, not a missing key.

**For Developer**: Do not add "skip if no API key" guards to tests. All integration paths should be exercised.

---

## [7] 2026-03-07T12:00 -- CTO

Re: Stack docs audit and update -- api.md, stack.md, setup.md refreshed for current state

### 1. api.md -- removed stale "not yet implemented" markers

The following endpoints were marked as not yet implemented but now exist in `routes.rb`:
- `GET /api/design-systems/:id` (show)
- `PATCH /api/design-systems/:id` (update)
- `DELETE /api/design-systems/:id` (destroy)
- `POST /api/design-systems/:id/figma-files` (add figma file)
- `DELETE /api/design-systems/:id/figma-files/:id` (remove figma file)
- `POST /api/designs/:id/reset` (revert iteration)
- `GET /api/design-systems/:id/renderer` (added -- was missing from catalog entirely)

All "not yet implemented" markers have been removed.

### 2. stack.md -- accuracy fixes

- **Procfile note removed**: The stale warning about `developer/api` paths was still in stack.md but the Procfile itself was already fixed.
- **Component list updated**: Added 17 missing Vue components to the Project Structure section (AIEngineSelector, AiSchemaView, AiSchemaNode, Button, CodeField, ComponentCard, ComponentStatusBadge, Loader, Logo, Menu, ProgressBar, Section, SectionHeader, Select, Snippet, VisualDiffOverlay, OnboardingStepOrganize).
- **Controller list updated**: Added `DesignSystemFigmaFilesController` (handles nested figma-files routes), alphabetized list.
- **Font reference updated**: Now reflects Suisse Int'l (@font-face "suiss") with system stack fallback + Menlo for code.

### 3. setup.md -- created

New file with:
- Prerequisites (Ruby 3.3.9, Node 20+, PostgreSQL 16+, Caddy)
- Install, database setup, clean rebuild instructions
- All environment variables for backend and frontend
- Dev server startup (`make dev`)
- Test commands (unit, E2E fast/workflow, render validation)
- Heroku deployment notes (Procfile processes)

### 4. Feature spec count: 10 files

Current feature specs (down from 18): 01-authentication, 02-health-check, 03-figma-import, 04-design-system-management, 05-design-generation, 06-design-improvement, 07-design-management, 08-component-library-browser, 09-visual-diff, 10-complex-figma-compatibility.

Deleted: 09-custom-components (was), 10-visual-diff (renumbered), 11-onboarding-wizard, 12-preview-rendering, 13-component-rendering-validation, 14-ai-task-pipeline, 15-component-svg-assets, 16-figma-json-inspection, 17-image-search, 18-ui-layout-and-design-system.

### 5. No stack changes

The technology stack remains the same. Rails 8 API + Vue 3 frontend + PostgreSQL + Auth0 + Heroku. No new dependencies needed for the current feature set.

### Note for Developer

The Makefile `test-e2e`, `test-render`, and `test-render-fresh` targets still reference `cd e2e &&` but primary E2E tests live in `.hats/qa/`. These Make targets may need updating if the legacy `e2e/` directory is removed.

---

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
