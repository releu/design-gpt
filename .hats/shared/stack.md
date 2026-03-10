# Technology Stack

## Language & Framework

- **Backend**: Ruby 3.3.9 / Rails 8.0.2 (API-only mode)
  - Rails API-only is the right fit: JSON endpoints, background jobs (Solid Queue), no server-rendered HTML except renderer pages (React/Babel in-browser compilation).
- **Frontend**: Vue 3 (Options API) / Vite 7 / JavaScript (no TypeScript)
  - Options API throughout, SCSS for styling, BEM naming with PascalCase blocks.
- **Reverse proxy**: Caddy (local development only)
  - Single entry point at `https://design-gpt.localtest.me`. Routes `/api/*` to Rails (port 3000), everything else to Vite (port 5173). Uses `tls internal` (self-signed). `.localtest.me` resolves to `127.0.0.1`.

## Database

- **PostgreSQL** (latest stable, 16+)
  - Relational domain model: users, designs, iterations, chat messages, AI tasks, design systems, figma files (component libraries), component sets, component variants, figma assets.
  - DB names: `jan_designer_api_development` / `jan_designer_api_test`.

## Authentication

- **Auth0** with RS256 JWT
  - Frontend: `@auth0/auth0-vue` plugin. Mock plugin (`test-support/mock-auth0.js`) loaded when `VITE_E2E_TEST=true` or `DEV` mode.
  - Backend: `Auth0Service.decode_token` decodes JWT (RS256 via JWKS). Auto-creates User on first login.
  - E2E mode: `E2E_TEST_MODE=true` accepts HS256 HMAC tokens signed with `e2e-test-secret-key`.
  - Test user: `auth0|alice123` / `alice@example.com`.

## External Services

- **Figma API** -- FigmaFile import pipeline (Client -> Importer -> AssetExtractor -> ReactFactory -> VisualDiff). Sync statuses: pending -> discovering -> importing -> converting -> comparing -> ready | error.
- **OpenAI API** -- design generation via structured output (gpt-5, JSON Schema). AiTask model with states: pending -> completed. AiRequestJob processes tasks.
- **Yandex Images** -- internal AI pipeline only. The AI generates text descriptions of images it needs; the backend resolves them to actual image URLs via Yandex Image Search. Not a user-facing feature.

## Project Structure

Code lives at the project root (Hats v3 layout):

```
app/                            # Vue 3 frontend
  src/
    main.js                     # Entry, global component registration, Auth0 (real or mock) + router
    App.vue                     # Root component
    assets/
      main.css                  # Global CSS variables, @font-face, design tokens
    components/                 # Auto-registered globally via import.meta.glob (*.vue)
                                # Includes: AIEngineSelector, AiSchemaNode, AiSchemaView,
                                #   Button, ChatPanel, CodeField, ComponentCard,
                                #   ComponentDetail, ComponentDetailModal, ComponentStatusBadge,
                                #   DesignSettings, DesignSystemModal, FigmaUrlInput,
                                #   Layout, LibraryCard, LibrarySelector, Loader, Logo,
                                #   MainLayout, Menu, OnboardingLayout, OnboardingStepComponents,
                                #   OnboardingStepLibraries, OnboardingStepOrganize,
                                #   OnboardingStepPrompt, Preview, ProgressBar, Prompt,
                                #   PromptField, Section, SectionHeader, Select, Snippet,
                                #   VisualDiffOverlay, WizardStepper
    views/                      # HomeView, DesignView, OnboardingView,
                                #   LibrariesView, LibraryDetailView
    router/index.js             # Routes: /, /designs/:id, /onboarding,
                                #   /libraries, /libraries/:id
    test-support/
      mock-auth0.js             # Mock Auth0 plugin (used in DEV mode and VITE_E2E_TEST=true)
    __tests__/
      setup.js                  # Vitest global setup
api/                            # Rails 8 API-only backend
  app/
    controllers/                # All scoped under /api
                                # ApplicationController, FigmaFilesController,
                                #   ComponentSetsController, ComponentsController,
                                #   CustomComponentsController, DesignSystemFigmaFilesController,
                                #   DesignSystemsController, DesignsController,
                                #   ImagesController, IterationsController,
                                #   RendersController, TasksController
      concerns/
        renderable.rb           # Shared renderer endpoint logic
    models/                     # Domain models
                                # Design, Iteration, ChatMessage, AiTask,
                                #   FigmaFile (FigmaFile), ComponentSet, ComponentVariant,
                                #   Component, FigmaAsset, DesignSystem,
                                #   DesignSystemLibrary (join), DesignFigmaFile (join),
                                #   Export, Render, User, DesignGenerator, ArtDirector
      concerns/
        component_naming.rb     # ComponentNaming shared concern
    services/                   # Plain Ruby services
      figma/                    # Client, Importer, ReactFactory, VisualDiff,
                                #   AssetExtractor, StyleExtractor, JsxCompiler,
                                #   ComponentResolver, SingleComponentImporter,
                                #   HtmlConverter
      exports/
        react_project_builder.rb
      auth0_service.rb
      json_to_jsx.rb
      yandex_images.rb
    jobs/                       # AiRequestJob, ScreenshotJob,
                                #   FigmaFileSyncJob (FigmaFileSyncJob), VisualDiffJob
  config/
  db/
caddy/                          # Reverse proxy (local dev only)
  Caddyfile
  certs/                        # Local TLS certificates (mkcert)
Makefile                        # dev, clean_dev, test, test-api, test-app,
                                #   test-e2e, test-render, test-render-fresh,
                                #   setup, setup-e2e targets
Procfile                        # Heroku process definitions (web, worker, release)
```

## Key Domain Relationships

```
User
  -> DesignSystems
       -> FigmaFiles (one per imported Figma file)
            -> ComponentSets (slots: [{name, allowed_children}]) -> ComponentVariants
            -> Components (slots: [{name, allowed_children}])
            -> FigmaAssets

User
  -> Designs
       -> linked to one DesignSystem (the component palette)
       -> Iterations (JSX snapshots)
       -> ChatMessages

AiTask (pending -> completed) -- linked to Iteration and Design
```

Note: `design_system_libraries` exists as a join table at the DB level linking DesignSystems to FigmaFiles, but it is not a domain concept and does not appear in user-facing specs or code logic.

Note: `DesignSystem` has an admin-only `is_public` field. When `true`, all users can see and use that design system. This field is set via Rails console — there is no API endpoint for it.

## Slots Data Model

The composition model uses **named slots** rather than a flat `allowed_children` array. Each component set (and standalone component) within a FigmaFile stores its slots as a JSONB array on the `slots` column. The old `allowed_children` column is removed.

### Database columns

| Table | Column | Type | Description |
|-------|--------|------|-------------|
| `component_sets` | `slots` | `jsonb` (default: `[]`) | Named slots for this component set |
| `components` | `slots` | `jsonb` (default: `[]`) | Named slots for this standalone component |

### Slot JSON structure

Each element in the `slots` array represents one named placeholder:

```json
[
  {
    "name": "content",
    "allowed_children": ["Title", "Button", "Card"]
  },
  {
    "name": "actions",
    "allowed_children": ["Button", "Link"]
  }
]
```

A component with no slots has `slots: []`. A component with a single unnamed slot (INSTANCE_SWAP with no explicit slot name) uses `"name": "children"` by convention.

### Why JSONB (not a separate table)

Slots are always read and written together with their parent component set. There is no use case for querying slots independently. JSONB keeps the model simple and avoids an extra join on every schema generation request.

### Detection at import time

Two Figma mechanisms produce slots (both are supported):

1. **Figma Slots API**: Figma exposes `slots` as a top-level property on component nodes. Each slot has a `name` and `preferredValues` listing the component keys that are valid in that slot. The importer reads these directly.

2. **INSTANCE_SWAP + `preferredValues`**: An alternative mechanism. The importer scans `componentPropertyDefinitions` for `INSTANCE_SWAP` type entries. Each such entry becomes one slot; its `preferredValues` become `allowed_children`. The property key (stripped of Figma's `#N` suffix) becomes the slot `name`.

### Figma Slots REST API response shape

When Figma Slots are enabled on a component, the raw `/v1/files/:key` response includes a `slots` array alongside `componentPropertyDefinitions`:

```json
{
  "componentPropertyDefinitions": { ... },
  "slots": [
    {
      "name": "content",
      "preferredValues": [
        { "type": "COMPONENT_SET", "key": "abc123" },
        { "type": "COMPONENT", "key": "def456" }
      ]
    }
  ]
}
```

The importer checks both `node["slots"]` and `componentPropertyDefinitions` (INSTANCE_SWAP entries) and merges the results.

### `#root` marker (unchanged)

Components marked with `#root` in Figma name or description have `is_root: true`. Root components are the valid top-level nodes in AI-generated designs. This mechanism is unchanged.

## Design Tokens

Global design tokens live in `src/assets/main.css` (`:root` CSS custom properties). See `.hats/designer/` for visual design specifications.

## Conventions

### Frontend
- **Options API** everywhere (`setup()` only for Auth0 composable)
- Component order: `<template>`, `<script>`, `<style lang="scss">`
- **Views** (`src/views/`) are pure composition -- no `<style>` section
- **Components** (`src/components/`) own all styles; BEM block = component name
- BEM naming: PascalCase block, `__kebab` element, `_kebab` modifier
- SCSS nesting via `&`: `&__element`, `&_modifier`
- Global tokens in `src/assets/main.css` (`:root` CSS variables)
- Font: Suisse Int'l (loaded via @font-face as "suiss"), with system stack fallback. Code font: Menlo, monospace.
- The right panel in DesignView has two modes: chat (default) and settings/component browser. A toggle controls which is shown.

### Backend
- Standard Rails conventions; no serializers (inline JSON rendering)
- Bang methods for writes (`create!`, `update!`)
- Strong params via private `*_params` methods
- `before_action :require_auth` for protected endpoints
- `current_user` decodes JWT, auto-creates User
- Read access: `accessible_*` / `find_accessible_*`. Write: `find_user_*` / `find_owned_*`
- Business logic in models (`Design#generate`, `Design#improve`)
- AI orchestration in `DesignGenerator` and `ArtDirector`
- Services: Plain Ruby under `app/services/`

### API Routes
- All scoped under `/api`; RESTful; no versioning prefix beyond `/api`
- Renderer endpoints (no auth): `/api/figma-files/:id/renderer`, `/api/design-systems/:id/renderer`, `/api/iterations/:id/renderer`
- Task endpoints use TASKS_TOKEN for external worker auth
- API endpoint catalog: see `.hats/shared/api.md`

### Testing
- **API**: RSpec, fixtures (no FactoryBot), WebMock for HTTP stubs
- **Frontend**: Vitest + @vue/test-utils + happy-dom, co-located `*.spec.js`
- **E2E**: Playwright + playwright-bdd (Gherkin BDD), real API calls (no mocks except auth), real Figma sync pipeline
- **API keys in test environment**: Real FIGMA_ACCESS_TOKEN and OPENAI_API_KEY are configured. E2E tests exercise full Figma import and AI generation pipelines. Do not assume keys are missing or skip tests on that basis — investigate actual errors instead.

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
- vue-codemirror (CodeMirror 6 -- JSX editing, read-only code display)
- vitest, @vue/test-utils, happy-dom (testing)

### E2E (.hats/qa/)
- @playwright/test
- playwright-bdd

## Hosting & Deployment

- **Target**: Heroku
- **Backend**: Heroku Ruby buildpack, Puma web process, Solid Queue worker process
- **Frontend**: Build static assets with Vite, serve via CDN or Heroku static buildpack
- **Database**: Heroku Postgres add-on
- **Proxy**: In production, Heroku handles HTTPS termination and routing; Caddy is local-dev only
- **Environment variables**: Auth0 credentials, OpenAI API key, Figma access token, database URL managed via Heroku config vars

---

## Design Generation Flow

### Technical Pipeline

1. **Import**: Components are imported from Figma (component sets with variants, standalone components, vectors). `is_root` is set from the `#root` marker. Named slots are detected from Figma Slots and/or INSTANCE_SWAP `preferredValues` — both are supported.

2. **Schema generation**: Backend builds a JSON Schema from the FigmaFiles in the selected DesignSystem — component names, props (extracted from variant names), `is_root` for top-level identification, named slots with `allowed_children` to constrain valid nesting per slot.

3. **AI request**: The prompt + JSON Schema are sent to the AI model as a structured output format. The AI returns valid JSON matching the component tree structure.

4. **Transform**: The returned JSON tree is transformed into JSX code via `JsonToJsx`.

5. **Render**: The JSX is sent via `postMessage` to the renderer iframe — an HTML page with React, ReactDOM, Babel, and all compiled FigmaFile components pre-loaded. Babel compiles JSX at runtime.

6. **Preview**: The rendered output is displayed in the preview iframe.

### Key Files by Step

| Step | Key files |
|------|-----------|
| 1. Import | `figma/client.rb`, `figma/importer.rb`, `figma/asset_extractor.rb`, `FigmaFileSyncJob` (FigmaFileSyncJob) |
| 2. Schema | `DesignGenerator#build_schema`, `#build_defs`, `ComponentNaming` concern |
| 3. AI request | `AiRequestJob`, `AiTask` model, OpenAI API (`gpt-5`, structured output) |
| 4. Transform | `JsonToJsx` service, `AiTask#jsx` |
| 5. Render | `Renderable` concern, renderer endpoints (no auth), React + Babel in HTML |
| 6. Preview | `Preview.vue`, `DesignView.vue` (polling + postMessage) |

---

## Figma Component Authoring Conventions

Special conventions in Figma that affect import and code generation.

### Figma Slots

When Slots are defined on a component in Figma, the `/v1/files/:key` API response includes a `slots` array on the component node. Each slot has a `name` and `preferredValues` listing the component keys valid in that slot.

At import time:
- Each Figma slot becomes one entry in the `slots` JSONB array: `{ "name": "...", "allowed_children": [...] }`.
- The slot's bound instance node becomes `{props.slotName}` (or `{props.children}` for the default/only slot) in the generated JSX at the exact position in the layout.
- No manual configuration in the app UI is required.

### INSTANCE_SWAP + `preferredValues`

An alternative way to define slots. The component has an INSTANCE_SWAP property in `componentPropertyDefinitions`; each such property becomes one slot. Its `preferredValues` become `allowed_children`; the property key (stripped of Figma's `#N` suffix) becomes the slot name.

Both Figma Slots and INSTANCE_SWAP + `preferredValues` are valid ways to define allowed children in Figma. The importer handles both. A component may use either mechanism — whichever the Figma file author chose.

### `#root` -- top-level component marker

Add `#root` anywhere in a component set's **name or description** in Figma. At import time, `is_root` is set to `true` automatically. Root components are used as the top-level node in the AI schema.

### `#list` -- list component marker

Add `#list` anywhere in a component set's **name or description** in Figma. The component is expected to have N identical INSTANCE nodes all bound to the same slot/INSTANCE_SWAP property. `ReactFactory` collapses all of them into a single `{props.children}`. The AI schema uses a direct `$ref` (not `anyOf`) to constrain children to the single item type.

Example: a `ListContainer #list` with 3 identical item placeholder instances generates JSX with one `{props.children}`; the slot's `allowed_children` is auto-set to the preferred item type.

### Figma TEXT properties

Text content that should be a dynamic prop must be defined as a TEXT property in Figma's component Properties panel, then bound to the text node via `componentPropertyReferences.characters`. The import reads these from `componentPropertyDefinitions` and stores them in `prop_definitions`. During code generation, any TEXT node with a `componentPropertyReferences.characters` reference is rendered as `{propName}` instead of static text. The AI schema requires these as string props.

### Example: Page component with a "content" slot

Figma structure of a `Page` component with a Slot named `content` (preferredValues: Title, Button):

```
Page (COMPONENT_SET)
  Slots: content (preferredValues: [Title, Button])
  Default variant (COMPONENT)
    Background (RECTANGLE)
    content placeholder (INSTANCE, bound to content slot)
```

Generated React code:

```jsx
export function Page(props) {
  return (
    <>
      <style>{styles}</style>
      <div className="root">
        <div className="background" />
        {props.children}  {/* replaces the bound slot instance, inside the layout */}
      </div>
    </>
  );
}
```

Import result: `slots = [{ "name": "content", "allowed_children": ["Title", "Button"] }]` auto-set on the Page component set.

---

## Terminology

See `.hats/shared/glossary.md` for canonical term definitions.

