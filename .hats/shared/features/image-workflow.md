# Image Workflow

## Overview

Components tagged with `#image` in their Figma name or description act as AI-driven image placeholders. When the AI generates a design, it fills these placeholders with search queries (e.g. "modern apartment building exterior"). The system searches Yandex Images, caches the result, and applies the image as a fill — both in the web preview (CSS background-image) and in Figma (IMAGE fill on the component instance).

## How it works

### 1. Figma Import

During `Figma::Importer#import`, components with `#image` in name/description get `is_image: true`. They're kept even if empty (they're intentional placeholders). Example: a component named `RandomImage` with description `#image`.

### 2. AI Design Generation

When the AI generates a design tree, it can reference components that have INSTANCE_SWAP properties pointing to `#image` components. The prompt text is passed as a property value:

```json
{
  "component": "BlockSuperads",
  "imageinstance": "modern apartment building exterior",
  "title": "ЖК Молжаниново"
}
```

### 3. Tree Builder (export)

`Exports::FigmaTreeBuilder` detects INSTANCE_SWAP props whose `preferredValues` point to `#image` component keys. These props are included in `textProperties` (not as instance swaps) so the Figma plugin can read the prompt text and fetch the image.

### 4. React Preview (web)

`Figma::ReactFactory` generates `<div>` with CSS `background-image` for image components:

- **Standalone `#image` component** → `generate_image_component_code()` outputs `<div style={{backgroundImage: url(...), backgroundSize: 'cover'}}>`
- **INSTANCE_SWAP pointing to `#image`** → inline `<div>` with background-image URL interpolation

Previously these used `<img>` tags with `objectFit: 'cover'`, which didn't match Figma's fill behavior.

### 5. Image endpoint

`GET /api/images/render?prompt=X` — no auth required:
1. Normalizes query (strip + downcase)
2. Checks `ImageCache` for cached result
3. On miss: calls Yandex Search API, caches URL/dimensions
4. Proxies the image bytes back with `Access-Control-Allow-Origin: *`
5. Returns 400 for blank prompt, 404 on error

The endpoint **proxies image bytes** instead of redirecting (302) because the Figma plugin runs in a sandboxed iframe with origin `null`, and cross-origin redirects are blocked by CORS.

### 6. Figma Plugin (image fill)

The tree-renderer in the plugin handles image fills in two phases:

**During render** (`renderComponentInstance`):
- For `isImage: true` nodes: collects `{nodeId, nodeName, prompt}` into `pendingImageFills`
- For INSTANCE_SWAP → `#image` props: finds the child instance via `componentPropertyReferences`, stores `{childName, prompt}` in `_pendingImageSwaps`

**After render** (`collectImageSwapFills`):
- Walks the final rendered frame to resolve child names to stable node IDs
- This must happen after `detachInstance()` which changes composite IDs

**Image apply** (`image-data` handler):
- UI fetches image bytes from `/api/images/render`
- Sends `image-data` message with bytes back to main thread
- Handler uses `figma.getNodeByIdAsync()` (required for `documentAccess: dynamic-page`)
- Falls back to name-based search within `__lastRootFrameId` if ID lookup fails

## Key files

| File | Role |
|------|------|
| `api/app/services/figma/importer.rb` | Sets `is_image: true` on import |
| `api/app/services/figma/react_factory.rb` | Generates `<div>` + background-image code |
| `api/app/services/exports/figma_tree_builder.rb` | Puts image prompts in `textProperties` |
| `api/app/controllers/images_controller.rb` | Proxies image bytes with CORS |
| `api/app/models/image_cache.rb` | Caches Yandex search results |
| `api/app/services/yandex_images.rb` | Calls Yandex Search API |
| `figma-plugin/src/tree-renderer.ts` | Collects `pendingImageFills` + `collectImageSwapFills()` |
| `figma-plugin/src/code.ts` / `dev-entry.ts` | `image-data` handler applies IMAGE fill |
| `figma-plugin/src/ui.html` | Fetches image bytes, sends `image-data` to main thread |

## Gotchas

1. **`documentAccess: dynamic-page`** — must use `figma.getNodeByIdAsync()`, not `figma.getNodeById()`. The sync version throws.
2. **Node IDs change after `detachInstance()`** — composite instance IDs like `I43978:70907;43941:3779` become invalid after the parent is detached. `collectImageSwapFills` resolves names to IDs post-render, and the `image-data` handler has a name-based fallback.
3. **CORS** — the image endpoint must include `Access-Control-Allow-Origin: *` because the Figma plugin UI runs from origin `null`. We proxy bytes instead of redirecting to avoid cross-origin redirect issues.
4. **INSTANCE_SWAP as text** — image prompts on INSTANCE_SWAP props are exported as `textProperties` (not as instance swaps) so the Figma plugin sees them as settable text. Figma's `setProperties()` won't accept text values for INSTANCE_SWAP type props, so the actual image fill is applied separately.
