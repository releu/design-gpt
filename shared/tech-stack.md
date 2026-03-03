# Technology Stack

## Language & Framework

- **Backend**: Ruby 3.3 / Rails 8 (API-only mode)
  - Matches the existing codebase. Rails API-only is the right fit: JSON endpoints, background jobs, no server-rendered HTML except renderer pages.
- **Frontend**: Vue 3 (Options API) / Vite 7 / JavaScript (no TypeScript)
  - Matches the existing codebase. Options API throughout, SCSS for styling.

## Database

- **PostgreSQL** (latest stable, currently 16+)
  - Already in use. Handles relational domain model (users, designs, component libraries, iterations, chat messages, AI tasks).

## Authentication

- **Auth0** with RS256 JWT
  - Frontend: `@auth0/auth0-vue`
  - Backend: `Auth0Service` decodes JWT, auto-creates User on first login
  - E2E mode: HS256 HMAC tokens signed with shared secret (`e2e-test-secret-key`)

## External Services

- **Figma API** -- component import pipeline (Client, Importer, AssetExtractor, ReactFactory, VisualDiff)
- **OpenAI API** -- design generation via structured output (gpt-5, JSON Schema)
- **Yandex Images** -- image search endpoint

## Project Structure

```
developer/
  app/                          # Vue 3 frontend
    src/
      main.js
      App.vue
      assets/main.css
      components/               # Auto-registered globally
      views/                    # HomeView, DesignView, OnboardingView, LibrariesView, LibraryDetailView
      router/index.js
  api/                          # Rails 8 API-only backend
    app/
      controllers/
      models/
      services/
        figma/
      jobs/
    config/
    db/
  caddy/                        # Reverse proxy
    Caddyfile
  e2e/                          # Playwright + playwright-bdd
    features/
    steps/
    fixtures/
```

## Conventions

- **Frontend**: Options API everywhere; BEM naming (PascalCase block); SCSS in SFCs; views have no styles; components own all styles
- **Backend**: Standard Rails conventions; no serializers (inline JSON rendering); bang methods for writes; strong params; `before_action :require_auth`
- **API routes**: All scoped under `/api`; RESTful; no versioning prefix beyond `/api`
- **Services**: Plain Ruby classes under `app/services/`; no callbacks for complex logic
- **Testing**: RSpec (API), Vitest + vue/test-utils (frontend), Playwright + playwright-bdd (E2E)

## Key Dependencies

### Backend (api/)
- rails ~> 8.0
- pg (PostgreSQL adapter)
- puma (app server)
- solid_queue, solid_cache, solid_cable (Rails 8 defaults)
- jwt (token decoding)
- rspec-rails, webmock (testing)

### Frontend (app/)
- vue ~> 3.x
- vue-router ~> 4.x
- vite ~> 7.x
- @auth0/auth0-vue
- vue-codemirror (CodeMirror 6)
- vitest, @vue/test-utils, happy-dom (testing)

### E2E (e2e/)
- @playwright/test
- playwright-bdd

## Hosting & Deployment

- **Target**: Heroku
- **Backend**: Heroku Ruby buildpack, Puma web process, Solid Queue worker process
- **Frontend**: Build static assets with Vite, serve via CDN or Heroku static buildpack
- **Database**: Heroku Postgres add-on
- **Proxy**: In production, Heroku handles HTTPS termination and routing; Caddy is local-dev only
- **Environment variables**: Auth0 credentials, OpenAI API key, Figma access token, database URL managed via Heroku config vars

## Setup Instructions

1. Clone the repo
2. `cd api && bundle install && bin/rails db:setup`
3. `cd app && npm install`
4. `cd e2e && npm install`
5. Copy `.env.example` to `.env` in `api/` and fill in Auth0, OpenAI, Figma credentials
6. `make dev` to start all services (Rails on 3000, Vite on 5173, Caddy on 443)
7. Visit `https://design-gpt.localtest.me`
