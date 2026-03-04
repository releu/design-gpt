# Setup Instructions

## Prerequisites

- Ruby 3.3.9 (via rbenv or asdf)
- Node.js 20+ (LTS)
- PostgreSQL 16+
- Caddy (for local HTTPS reverse proxy)

## Initial Setup

### 1. Clone and install dependencies

```sh
git clone <repo-url> && cd designgpt

# Backend
cd api
bundle install
bin/rails db:setup    # Creates jan_designer_api_development + test DBs, runs migrations + seeds
cd ..

# Frontend
cd app
npm install
cd ..

# E2E tests
cd .hats/qa
npm install
npx playwright install    # Install browser binaries
cd ../..
```

### 2. Configure environment variables

Copy `api/.env.example` to `api/.env` and fill in:

```
# Auth0
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://your-api-identifier
AUTH0_CLIENT_ID=your-client-id

# OpenAI
OPENAI_API_KEY=sk-...

# Figma
FIGMA_TOKEN=figd_...

# E2E testing (optional, for running E2E tests)
E2E_TEST_MODE=true
```

Frontend env vars go in `app/.env.local`:

```
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
VITE_AUTH0_AUDIENCE=https://your-api-identifier
```

### 3. Start development

```sh
# All at once (recommended):
make dev

# Or individually in separate terminals:
cd api && bin/rails server                # Terminal 1 -- port 3000
cd app && npm run dev                     # Terminal 2 -- port 5173
cd caddy && caddy run --config Caddyfile  # Terminal 3 -- port 443

# Visit:
# https://design-gpt.localtest.me
```

## Running Tests

```sh
make test        # API + frontend unit tests (fast, no servers needed)
make test-api    # API only (RSpec)
make test-app    # Frontend only (Vitest)
make test-e2e    # E2E (starts servers, requires Figma token for import tests)
```

### E2E test notes

- E2E tests require all three services running (Rails, Vite, Caddy)
- `make test-e2e` starts them automatically via Playwright `webServer` config
- Tests that sync from Figma require a valid `FIGMA_TOKEN` in `api/.env`
- Import tests have `@timeout:600000` (10 minutes) -- Figma syncs take 8-10 minutes
- Auth is mocked with HS256 HMAC tokens; no real Auth0 calls during E2E
- DB is reset to a single test user before each run (`rails e2e:setup`)

## Database

- Development: `jan_designer_api_development`
- Test: `jan_designer_api_test`

```sh
cd api
bin/rails db:migrate         # Run pending migrations
bin/rails db:test:prepare    # Prepare test DB
bin/rails db:seed            # Seed development data
```

## Caddy / HTTPS

Caddy provides local HTTPS with `tls internal` (self-signed cert). The domain `design-gpt.localtest.me` resolves to `127.0.0.1` via public DNS (no /etc/hosts editing needed). Your browser will warn about the self-signed cert on first visit -- accept it to proceed.

---

## Test Suite Organization

### Primary E2E suite: `.hats/qa/`

The `.hats/qa/` directory contains the primary E2E test suite (19 features, 134 scenarios). It uses Playwright + playwright-bdd with Gherkin feature files. This suite supersedes the legacy `e2e/` directory.

### Dev tests (co-located)

- **API**: RSpec specs in `api/spec/`. Fixtures in `api/test/fixtures/*.yml` (no FactoryBot). Auth helpers in `spec/support/auth_helper.rb`. WebMock for HTTP stubs.
- **Frontend**: Vitest specs co-located as `*.spec.js` next to components in `app/src/`. Config in `app/vitest.config.js`. Auth mock in `app/src/__tests__/setup.js`.

### Legacy: `e2e/` (to be removed)

The `e2e/` directory is the original E2E test suite. It has been fully superseded by `.hats/qa/` which has 20x the coverage. Scheduled for deletion.

---

## Writing Strong Tests

**Every assertion must verify the actual outcome, not a proxy for it.** A test that checks a container exists without checking its content is a weak test -- it passes even when the feature is broken.

Rules:

- **Assert on content, not containers.** Don't just check that an element is visible -- check that it contains the expected data. An empty iframe, an empty list, or a spinner that never resolves are all "visible" but broken.
- **Assert inside iframes.** Use `page.frameLocator()` to reach into iframe content. Checking iframe `src` or visibility proves nothing about what rendered inside.
- **Assert on user-visible text.** If the feature shows data to the user (names, numbers, messages), assert on that text. Use `toContainText`, `toHaveText`, or content checks -- not `toBeVisible` alone.
- **Never treat "element exists" as "feature works."** A loading spinner, error message, or empty state are all existing elements. The test must distinguish success from these failure modes.
- **Test the specific outcome.** If the prompt is "rivers in Belgrade", assert the preview contains actual river names. If import creates components, assert the component names appear in the UI. Generic "something rendered" checks catch nothing.
- **Prefer `not.toBeEmpty()` over `toBeVisible()` for content areas.** An empty `#root` div is visible but useless.
- **Always end E2E scenarios with `And there are no console errors`.** Rendering failures, JS exceptions, and network errors all surface in the console.
