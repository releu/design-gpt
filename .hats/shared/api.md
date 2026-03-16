# API Conventions

## Base URL

All endpoints are scoped under `/api`. The frontend accesses them via Caddy at `https://design-gpt.localtest.me/api/*`.

## Authentication

- All endpoints require `Authorization: Bearer <JWT>` header unless noted otherwise
- Unauthenticated endpoints: renderer pages (`/api/figma-files/:id/renderer`, `/api/design-systems/:id/renderer`, `/api/iterations/:id/renderer`), health check (`/api/up`), Figma JSON (`/api/components/:id/figma-json`, `/api/component-sets/:id/figma-json`), SVG assets (`/api/components/:id/svg`, `/api/component-sets/:id/svg`), HTML preview (`/api/components/:id/html-preview`), library preview page (`/api/figma-files/:id/preview`)
- Task endpoints (`/api/tasks/*`) use `TASKS_TOKEN` header auth instead of JWT

## Response Format

- All responses are JSON (no serializer layer -- inline rendering in controllers)
- Success: HTTP 200/201/204 with JSON body (or empty body for 204)
- Error: HTTP 4xx/5xx with JSON `{ "error": "message" }` or Rails default error format
- 404 for "not found" and "not authorized to access" (no distinction to prevent enumeration)

## Endpoint Catalog

### Health
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/up | No | Health check |

### Design Systems
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/design-systems | Yes | List user's design systems |
| POST | /api/design-systems | Yes | Create (name + figma_file URLs to import) |
| GET | /api/design-systems/:id | Yes | Show single design system with its FigmaFiles |
| PATCH | /api/design-systems/:id | Yes | Update name and/or linked FigmaFiles |
| DELETE | /api/design-systems/:id | Yes | Delete design system |
| GET | /api/design-systems/:id/renderer | No | Renderer combining all libraries in this design system |
| POST | /api/design-systems/:id/figma-files | Yes | Add a FigmaFile to an existing design system |
| DELETE | /api/design-systems/:id/figma-files/:figma_file_id | Yes | Remove a FigmaFile from a design system |

### FigmaFiles
_(URL paths use `/api/figma-files/`.)_

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/figma-files | Yes | List own FigmaFiles |
| GET | /api/figma-files/available | Yes | Own + public FigmaFiles |
| POST | /api/figma-files | Yes | Create (import from Figma URL) |
| GET | /api/figma-files/:id | Yes | Show FigmaFile with components |
| PATCH | /api/figma-files/:id | Yes | Update name |
| POST | /api/figma-files/:id/sync | Yes | Re-sync from Figma (async) |
| GET | /api/figma-files/:id/components | Yes | List all component sets and components |
| GET | /api/figma-files/:id/renderer | No | Iframe renderer HTML |
| GET | /api/figma-files/:id/preview | No | Preview page (all components) |

### Component Sets
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| PATCH | /api/component-sets/:id | Yes | Update is_root, slots |
| POST | /api/component-sets/:id/reimport | Yes | Re-import single component set |
| GET | /api/component-sets/:id/figma-json | No | Raw Figma JSON |
| GET | /api/component-sets/:id/svg | No | SVG asset |

### Components
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| PATCH | /api/components/:id | Yes | Update component fields |
| POST | /api/components/:id/reimport | Yes | Re-import single component |
| GET | /api/components/:id/visual-diff | Yes | Visual diff results |
| GET | /api/components/:id/diff-image | Yes | Diff PNG |
| GET | /api/components/:id/screenshots/:type | Yes | Figma or React screenshot PNG |
| GET | /api/components/:id/figma-json | No | Raw Figma JSON |
| GET | /api/components/:id/svg | No | SVG asset |
| GET | /api/components/:id/html-preview | No | Standalone HTML preview |

### Custom Components

_No feature spec. Status TBD._

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/custom-components | Yes | Upload custom React component |
| PATCH | /api/custom-components/:id | Yes | Update |
| DELETE | /api/custom-components/:id | Yes | Delete |

### Designs
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/designs | Yes | List user's designs |
| POST | /api/designs | Yes | Create (prompt + design_system_id) |
| GET | /api/designs/:id | Yes | Show design + iterations + chat |
| PATCH | /api/designs/:id | Yes | Update name |
| DELETE | /api/designs/:id | Yes | Delete |
| POST | /api/designs/:id/improve | Yes | Chat improvement (new iteration); request body must include full chat history |
| POST | /api/designs/:id/reset | Yes | Revert design to previous iteration |
| POST | /api/designs/:id/apply/:message_id | Yes | Apply art director comments (route live; feature currently disabled) |
| POST | /api/designs/:id/duplicate | Yes | Duplicate design |
| GET | /api/designs/:id/export-image | Yes | Export as PNG |
| GET | /api/designs/:id/export-react | Yes | Export as React project zip |
| GET | /api/designs/:id/export-figma | Yes | Returns a code for copy-pasting into the DesignGPT Figma plugin |

### Renders
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/renders/:id | Yes | Show a stored render record |

### Renderers (no auth)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/design-systems/:id/renderer | No | Renderer combining all libraries |
| GET | /api/iterations/:id/renderer | No | Renderer for specific iteration |

### AI Tasks
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/tasks/next | Token | Poll for next pending task |
| GET | /api/tasks/:id | Token | Show task details + JSX |
| PATCH | /api/tasks/:id | Token | Complete task with result |

### Images (internal)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/images | Yes | Image search used internally by AI pipeline (q= param). Not a user-facing feature. |

## Design Status Flow

```
draft -> generating -> ready
                   \-> error
```

- `POST /api/designs` sets status to `generating` and enqueues `AiRequestJob`
- `POST /api/designs/:id/improve` resets status to `generating` and enqueues a new `AiRequestJob`
- Frontend polls `GET /api/designs/:id` every 1s while status is `generating`
- Polling stops when status changes to `ready` or `error`

## FigmaFile Sync Flow

```
pending -> importing -> converting -> comparing -> ready
                                               \-> error
```

- `POST /api/figma-files` creates a FigmaFile record with status `pending`
- `POST /api/figma-files/:id/sync` enqueues `FigmaFileSyncJob` (FigmaFileSyncJob)
- Frontend polls `GET /api/figma-files/:id` for progress updates
- Progress object: `{ step_number, total_steps, message }`

## Renderer Communication Protocol

The renderer pages (served as HTML) include React 18, ReactDOM 18, Babel standalone, and all compiled component code. Communication with the parent frame uses `postMessage`:

1. Renderer sends `{ type: "ready" }` to parent when loaded
2. Parent sends `{ type: "render", jsx: "<ComponentTree />" }` to renderer
3. Renderer compiles JSX via Babel, renders into `#root` with React
4. On error, renderer catches and displays error in `#root`
