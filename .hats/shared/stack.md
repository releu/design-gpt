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
  - Relational domain model: users, designs, iterations, chat messages, AI tasks, design systems, component libraries, component sets, component variants, figma assets.
  - DB names: `jan_designer_api_development` / `jan_designer_api_test`.

## Authentication

- **Auth0** with RS256 JWT
  - Frontend: `@auth0/auth0-vue` plugin. Mock plugin when `VITE_E2E_TEST=true`.
  - Backend: `Auth0Service.decode_token` decodes JWT (RS256 via JWKS). Auto-creates User on first login.
  - E2E mode: `E2E_TEST_MODE=true` accepts HS256 HMAC tokens signed with `e2e-test-secret-key`.
  - Test user: `auth0|alice123` / `alice@example.com`.

## External Services

- **Figma API** -- component import pipeline (Client -> Importer -> AssetExtractor -> ReactFactory -> VisualDiff). Sync statuses: pending -> discovering -> importing -> converting -> comparing -> ready | error.
- **OpenAI API** -- design generation via structured output (gpt-5, JSON Schema). AiTask model with states: pending -> completed. AiRequestJob processes tasks.
- **Yandex Images** -- image search endpoint (GET /api/images?q=query).

## Project Structure

Code lives at the project root (Hats v3 layout):

```
app/                            # Vue 3 frontend
  src/
    main.js                     # Entry, global component registration, Auth0 + router
    App.vue                     # Root, Auth0 gate
    assets/main.css             # Global CSS variables, @font-face, design tokens
    components/                 # Auto-registered globally via import.meta.glob
    views/                      # HomeView, DesignView, OnboardingView, LibrariesView, LibraryDetailView
    router/index.js             # Routes: /, /designs/:id, /onboarding, /libraries, /libraries/:id
api/                            # Rails 8 API-only backend
  app/
    controllers/                # All scoped under /api
    models/                     # Domain models + DesignGenerator, ArtDirector
    services/                   # Plain Ruby services
      figma/                    # Client, Importer, ReactFactory, VisualDiff, AssetExtractor, StyleExtractor
    jobs/                       # AiRequestJob, ScreenshotJob, ComponentLibrarySyncJob
  config/
  db/
caddy/                          # Reverse proxy (local dev only)
  Caddyfile
e2e/                            # Playwright + playwright-bdd
  features/                     # Gherkin feature files
  steps/                        # Step definitions (createBdd from playwright-bdd)
  fixtures/                     # Custom fixtures: consoleErrors, world
Makefile                        # dev, test, test-api, test-app, test-e2e targets
```

## Key Domain Relationships

```
User -> DesignSystems -> DesignSystemLibraries -> ComponentLibraries -> Components
                                                                     -> ComponentSets -> ComponentVariants
                                                                     -> FigmaAssets
User -> Designs -> Iterations (JSX snapshots)
                -> ChatMessages
                -> DesignComponentLibraries -> ComponentLibraries
AiTask (pending -> completed) -- linked to Iteration and Design
```

## Design Tokens (CSS Custom Properties)

The designer has specified a warm monochrome design system. All tokens live in `src/assets/main.css`:

### Colors
| Token | Value | Usage |
|-------|-------|-------|
| `--bg-page` | `#EBEBEA` | Page background |
| `--bg-panel` | `#FFFFFF` | Card/panel surfaces |
| `--bg-input` | `#FFFFFF` | Text inputs, textareas |
| `--bg-bubble-user` | `#F0EFED` | AI/designer chat bubbles |
| `--bg-chip-active` | `#EBEBEA` | Selected pills/chips |
| `--bg-modal-overlay` | `#EBEBEA` | Modal overlay |
| `--text-primary` | `#1A1A1A` | Body text, labels |
| `--text-secondary` | `#999999` | Placeholder, muted text |
| `--text-on-dark` | `#FFFFFF` | Text on dark buttons |
| `--accent-primary` | `#1A1A1A` | Generate/send button fill |
| `--accent-border` | `#D4D4D4` | Subtle 1px borders |
| `--accent-divider` | `#E0E0E0` | Drag-handle divider lines |

### Spacing (8px grid)
| Token | Value | Usage |
|-------|-------|-------|
| `--sp-1` | 4px | Tight internal padding |
| `--sp-2` | 8px | Default padding, small gaps |
| `--sp-3` | 16px | Panel padding, component gaps |
| `--sp-4` | 24px | Larger section spacing |
| `--sp-5` | 32px | Outer page margin |
| `--sp-6` | 48px | Modal content from edges |

### Border Radius
| Token | Value | Usage |
|-------|-------|-------|
| `--radius-sm` | 8px | Chips, badges |
| `--radius-md` | 16px | Cards, panels, inputs, buttons, bubbles |
| `--radius-lg` | 24px | Large containers, modals, desktop preview |
| `--radius-pill` | 9999px | Header toggles, generate button |
| `--radius-phone` | 72px | Phone preview frame |

### Z-Index
| Layer | z-index | Content |
|-------|---------|---------|
| Base | 0 | Page, panels |
| Dropdown | 100 | Design selector, export menu |
| Modal overlay | 200 | DS modal overlay |
| Modal content | 201 | DS modal card |
| Toast | 300 | Notifications |

## Conventions

### Frontend
- **Options API** everywhere (`setup()` only for Auth0 composable)
- Component order: `<template>`, `<script>`, `<style lang="scss">`
- **Views** (`src/views/`) are pure composition -- no `<style>` section
- **Components** (`src/components/`) own all styles; BEM block = component name
- BEM naming: PascalCase block, `__kebab` element, `_kebab` modifier
- SCSS nesting via `&`: `&__element`, `&_modifier`
- Global tokens in `src/assets/main.css` (`:root` CSS variables)
- Font: `-apple-system, BlinkMacSystemFont, Inter, Segoe UI, Roboto, sans-serif`
- Desktop-only: min 1200x600, no mobile/tablet breakpoints
- All labels lowercase, no uppercase transforms
- No page scroll -- panel-internal scrolling only

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
- Renderer endpoints (no auth): `/api/component-libraries/:id/renderer`, `/api/design-systems/:id/renderer`, `/api/iterations/:id/renderer`
- Task endpoints use TASKS_TOKEN for external worker auth

### Testing
- **API**: RSpec, fixtures (no FactoryBot), WebMock for HTTP stubs
- **Frontend**: Vitest + @vue/test-utils + happy-dom, co-located `*.spec.js`
- **E2E**: Playwright + playwright-bdd (Gherkin BDD), real API calls (no mocks except auth), real Figma sync pipeline

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

---

## Design Generation Flow

### 8-Step Pipeline

1. **Import**: User provides Figma file URLs. The system imports all components (component sets with variants, standalone components, icons). `is_root` and `allowed_children` are set automatically from Figma conventions (`#root` marker, INSTANCE_SWAP `preferredValues`).

2. **Configure**: User names the design system and groups the imported libraries into it. `is_root` and `allowed_children` are auto-set from Figma conventions at import time but remain editable in the UI -- the user can optionally adjust them.

3. **Prompt**: User writes a text prompt describing the desired design.

4. **Schema generation**: Backend builds a JSON Schema from the component library -- component names, their props (extracted from variant names), `is_root` to identify top-level components, `allowed_children` to constrain valid nesting.

5. **AI request**: The prompt + JSON Schema are sent to the AI model. The schema is passed as the structured output format so the AI generates valid JSON matching the component tree structure.

6. **Transform**: The returned JSON tree is transformed into JSX code using the component names and props.

7. **Render**: The JSX is sent via `postMessage` to the renderer iframe -- an HTML page with React, ReactDOM, Babel, and all the library's compiled React components pre-loaded. Babel compiles the JSX at runtime, and React renders it.

8. **Preview**: The rendered result appears in the preview iframe (mobile or desktop layout).

### Key Files by Step

| Step | Key files |
|------|-----------|
| 1. Import | `figma/client.rb`, `figma/importer.rb`, `figma/asset_extractor.rb`, `ComponentLibrarySyncJob` |
| 2. Configure | `DesignSystemModal.vue`, `ComponentSetsController`, `DesignSystem` model |
| 3. Prompt | `Prompt.vue`, `HomeView.vue`, `DesignsController#create` |
| 4. Schema | `DesignGenerator#build_schema`, `#build_defs`, `ComponentNaming` concern |
| 5. AI request | `AiRequestJob`, `AiTask` model, OpenAI API (`gpt-5`, structured output) |
| 6. Transform | `JsonToJsx` service, `AiTask#jsx` |
| 7. Render | `Renderable` concern, renderer endpoints (no auth), React + Babel in HTML |
| 8. Preview | `Preview.vue`, `DesignView.vue` (polling + postMessage) |

---

## Figma Component Authoring Conventions

Special conventions in Figma that affect import and code generation.

### INSTANCE_SWAP + `preferredValues` (primary slot convention)

Components in Figma often contain a placeholder instance where child content should be inserted at runtime. `ReactFactory` detects the slot position from the Figma component definition and replaces it with `{props.children}` in the generated JSX -- at the exact position inside the layout.

Create an INSTANCE_SWAP property in Figma's component Properties panel and bind it to an instance node (the placeholder). Add `preferredValues` to the property listing the component sets that are valid children. At import time:
- The bound instance node becomes `{props.children}` in the generated JSX.
- `preferredValues` is resolved to component names and `allowed_children` is auto-set on the component set.
- No manual configuration in the app UI is required.

### `#root` -- top-level component marker

Add `#root` anywhere in a component set's **name or description** in Figma. At import time, `is_root` is set to `true` automatically. Root components are used as the top-level node in the AI schema.

### `#list` -- list component marker

Add `#list` anywhere in a component set's **name or description** in Figma. The component is expected to have N identical INSTANCE nodes all bound to the same INSTANCE_SWAP property. `ReactFactory` collapses all of them into a single `{props.children}`. The AI schema uses a direct `$ref` (not `anyOf`) to constrain children to the single item type.

Example: a `ListContainer #list` with 3 identical item placeholder instances generates JSX with one `{props.children}`; `allowed_children` is auto-set to the preferred item type.

### Figma TEXT properties

Text content that should be a dynamic prop must be defined as a TEXT property in Figma's component Properties panel, then bound to the text node via `componentPropertyReferences.characters`. The import reads these from `componentPropertyDefinitions` and stores them in `prop_definitions`. During code generation, any TEXT node with a `componentPropertyReferences.characters` reference is rendered as `{propName}` instead of static text. The AI schema requires these as string props.

### Example: Page component with children slot

Figma structure of a `Page` component with an INSTANCE_SWAP property named `Content` (preferredValues: Title, Button):

```
Page (COMPONENT_SET)
  Properties: Content (INSTANCE_SWAP, preferredValues: [Title, Button])
  Default variant (COMPONENT)
    Background (RECTANGLE)
    content placeholder (INSTANCE, bound to Content property)
```

Generated React code:

```jsx
export function Page(props) {
  return (
    <>
      <style>{styles}</style>
      <div className="root">
        <div className="background" />
        {props.children}  {/* replaces the bound instance, inside the layout */}
      </div>
    </>
  );
}
```

Import result: `allowed_children = ["Title", "Button"]` auto-set on the Page component set.

---

## Known Issues

- **ChatMessage model**: No `belongs_to :design` declared -- use `design_id` column directly in fixtures.
- **Art director disabled**: `ScreenshotJob` no longer triggers `analyze_last_render` -- art director flow is commented out pending re-enablement.
