# API Conventions

## Base URL

All endpoints are scoped under `/api`. The frontend accesses them via Caddy at `https://design-gpt.localtest.me/api/*`.

## Authentication

- All endpoints require `Authorization: Bearer <JWT>` header unless noted otherwise
- Unauthenticated endpoints: renderer pages (`/api/component-libraries/:id/renderer`, `/api/design-systems/:id/renderer`, `/api/iterations/:id/renderer`), health check (`/api/up`), Figma JSON inspection, component SVG/HTML endpoints
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
| POST | /api/design-systems | Yes | Create (name + component_library_ids) |

### Component Libraries
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/component-libraries | Yes | List own libraries |
| GET | /api/component-libraries/available | Yes | Own + public libs |
| POST | /api/component-libraries | Yes | Create (import from Figma URL) |
| GET | /api/component-libraries/:id | Yes | Show with components |
| PATCH | /api/component-libraries/:id | Yes | Update name, is_public |
| POST | /api/component-libraries/:id/sync | Yes | Re-sync from Figma (async) |
| GET | /api/component-libraries/:id/components | Yes | List components |
| GET | /api/component-libraries/:id/renderer | No | Iframe renderer HTML |
| GET | /api/component-libraries/:id/preview | No | Preview page (all components) |

### Component Sets
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| PATCH | /api/component-sets/:id | Yes | Update is_root, allowed_children |
| POST | /api/component-sets/:id/reimport | Yes | Re-import single component set |
| GET | /api/component-sets/:id/figma_json | No | Raw Figma JSON |
| GET | /api/component-sets/:id/svg | No | SVG asset |

### Components
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/components/:id/reimport | Yes | Re-import single component |
| GET | /api/components/:id/visual_diff | Yes | Visual diff results |
| GET | /api/components/:id/diff_image | Yes | Diff PNG |
| GET | /api/components/:id/screenshots/:type | Yes | Figma or React screenshot PNG |
| GET | /api/components/:id/figma_json | No | Raw Figma JSON |
| GET | /api/components/:id/svg | No | SVG asset |
| GET | /api/components/:id/html_preview | No | Standalone HTML preview |

### Custom Components
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/custom-components | Yes | Upload custom React component |
| PATCH | /api/custom-components/:id | Yes | Update |
| DELETE | /api/custom-components/:id | Yes | Delete |

### Designs
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/designs | Yes | List user's designs |
| POST | /api/designs | Yes | Create (prompt + design_system_id or component_library_ids) |
| GET | /api/designs/:id | Yes | Show design + iterations + chat |
| PATCH | /api/designs/:id | Yes | Update name |
| DELETE | /api/designs/:id | Yes | Delete |
| POST | /api/designs/:id/improve | Yes | Chat improvement (new iteration) |
| POST | /api/designs/:id/duplicate | Yes | Duplicate design |
| GET | /api/designs/:id/export_image | Yes | Export as PNG |
| GET | /api/designs/:id/export_react | Yes | Export as React project zip |
| GET | /api/designs/:id/export_figma | Yes | Export tree JSON for Figma |

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

### Images
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/images | Yes | Search images (q= param) |

## Design Status Flow

```
draft -> generating -> ready
                   \-> error
```

- `POST /api/designs` sets status to `generating` and enqueues `AiRequestJob`
- `POST /api/designs/:id/improve` resets status to `generating` and enqueues a new `AiRequestJob`
- Frontend polls `GET /api/designs/:id` every 1s while status is `generating`
- Polling stops when status changes to `ready` or `error`

## Component Library Sync Flow

```
pending -> discovering -> importing -> converting -> comparing -> ready
                                                              \-> error
```

- `POST /api/component-libraries` creates with status `pending`
- `POST /api/component-libraries/:id/sync` enqueues `ComponentLibrarySyncJob`
- Frontend polls `GET /api/component-libraries/:id` for progress updates
- Progress object: `{ step_number, total_steps, message }`

## Renderer Communication Protocol

The renderer pages (served as HTML) include React 18, ReactDOM 18, Babel standalone, and all compiled component code. Communication with the parent frame uses `postMessage`:

1. Renderer sends `{ type: "ready" }` to parent when loaded
2. Parent sends `{ type: "render", jsx: "<ComponentTree />" }` to renderer
3. Renderer compiles JSX via Babel, renders into `#root` with React
4. On error, renderer catches and displays error in `#root`
