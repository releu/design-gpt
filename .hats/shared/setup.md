# Setup Instructions

## Prerequisites

- Ruby 3.3.9 (via rbenv/asdf)
- Node.js 20+ (via nvm/asdf)
- PostgreSQL 16+
- Caddy (for local HTTPS proxy)

## Install Dependencies

```bash
make setup
```

This runs:
- `cd app && npm install` (Vue frontend)
- `cd api && bundle install` (Rails backend)
- `cd e2e && npm install && npx playwright install chromium` (E2E tests -- note: e2e/ is legacy, primary E2E lives in .hats/qa/)

## Database Setup

```bash
cd api && bin/rails db:create db:migrate
```

Database names: `jan_designer_api_development` / `jan_designer_api_test`.

To rebuild from scratch:

```bash
make clean_dev
```

This drops, recreates, migrates the DB, then starts dev servers.

## Environment Variables

### Backend (api/)

| Variable | Purpose |
|----------|---------|
| `AUTH0_DOMAIN` | Auth0 tenant domain |
| `AUTH0_AUDIENCE` | Auth0 API audience identifier |
| `AUTH0_CLIENT_ID` | Auth0 application client ID |
| `AUTH0_CLIENT_SECRET` | Auth0 application client secret |
| `OPENAI_API_KEY` | OpenAI API key (gpt-5 structured output) |
| `FIGMA_TOKEN` | Figma personal access token |
| `TASKS_TOKEN` | Shared secret for AI task worker endpoints |
| `E2E_TEST_MODE` | Set to `true` to accept HS256 test tokens |
| `DATABASE_URL` | PostgreSQL connection string (production only) |

### Frontend (app/)

| Variable | Purpose |
|----------|---------|
| `VITE_AUTH0_DOMAIN` | Auth0 tenant domain |
| `VITE_AUTH0_CLIENT_ID` | Auth0 application client ID |
| `VITE_AUTH0_AUDIENCE` | Auth0 API audience |
| `VITE_E2E_TEST` | Set to `true` to use mock Auth0 plugin |

## Start Development

```bash
make dev
```

This starts three processes:
- Rails API server on port 3000
- Vite dev server on port 5173
- Caddy reverse proxy

Access the app at: `https://design-gpt.localtest.me`

Caddy routes `/api/*` to Rails and everything else to Vite. Uses `tls internal` (self-signed certificates). `.localtest.me` resolves to `127.0.0.1` by DNS.

## Running Tests

### Unit/Integration Tests

```bash
make test          # Runs both API and frontend tests
make test-api      # RSpec (api/)
make test-app      # Vitest (app/)
```

### E2E Tests

Primary E2E tests live in `.hats/qa/` (Playwright + playwright-bdd with Gherkin specs from `.hats/manager/`).

```bash
cd .hats/qa && npx bddgen && npx playwright test                    # Fast suite
cd .hats/qa && npx bddgen && npx playwright test --config playwright.workflow.config.js  # Workflow suite
```

The E2E tests require:
- `FIGMA_TOKEN` set (real Figma API calls, no mocks)
- `E2E_TEST_MODE=true` on the Rails server (accepts HS256 test tokens)
- Dev servers running (`make dev`)
- Test user: `auth0|alice123` / `alice@example.com`

### Component Rendering Validation

```bash
make test-render        # Reuses existing Figma import
make test-render-fresh  # Fresh DB + Figma import (FORCE=1)
```

## Deployment (Heroku)

The `Procfile` defines three processes:
- `web`: Rails server (`cd api && bin/rails server -p $PORT -b 0.0.0.0`)
- `worker`: Solid Queue job processor (`cd api && bin/jobs`)
- `release`: Database migrations (`cd api && bin/rails db:migrate`)

Environment variables are configured via Heroku config vars.
