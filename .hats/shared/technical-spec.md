# Technical Specification: Figma-to-React Pipeline

> This document describes the complete pipeline from importing a Figma design system to rendering React components in the browser. It is language-agnostic and focuses on algorithms, data transformations, and contracts — sufficient to rewrite the system in another language.

## Overview

```
Figma File (cloud)
  ↓ REST API
Import (structure + metadata)
  ↓
Asset Extraction (SVG vectors, PNG rasters)
  ↓
Code Generation (Figma JSON → React JSX → compiled JS)
  ↓
Rendering (HTML page with React 18, compiled components, Babel for live JSX)
  ↓
AI Generation (JSON Schema → AI → JSON tree → JSX → render)
```

---

## 1. Data Model

### Core Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `design_systems` | User-created collection of Figma files | name, status, version, user_id, is_public, progress (JSONB) |
| `figma_files` | One imported Figma file | figma_file_key, version, status, design_system_id, component_key_map (JSONB), figma_last_modified |
| `component_sets` | Figma COMPONENT_SET (has variants) | node_id, name, figma_file_id, prop_definitions (JSONB), slots (JSONB), is_root, is_image, content_hash, validation_warnings (JSONB) |
| `component_variants` | One variant inside a component set | node_id, component_set_id, name, figma_json (JSONB), react_code, react_code_compiled, is_default, component_key, content_hash |
| `components` | Standalone component (no variants) | node_id, name, figma_file_id, figma_json (JSONB), react_code, react_code_compiled, prop_definitions, slots, is_root, is_image, component_key, content_hash, validation_warnings (JSONB) |
| `figma_assets` | SVG/PNG content for vector/raster nodes | node_id, asset_type (svg/png), content (text), component_id, component_set_id |

### Relationships

```
DesignSystem 1→N FigmaFile (via design_system_id + version)
FigmaFile 1→N ComponentSet 1→N ComponentVariant
FigmaFile 1→N Component (standalone)
ComponentSet/Component 1→N FigmaAsset
```

### Versioning

Each sync increments `design_system.version`. New FigmaFile records are created at the new version. Old versions are retained so iterations render with their original components.

`current_figma_files` = `figma_files.where(version: design_system.version)`

---

## 2. Figma API Contracts

### Endpoints Used

| Endpoint | Purpose | Response Shape |
|----------|---------|----------------|
| `GET /v1/files/{key}` | Full file with document tree | `{ document, components: { nodeId: { name, key, componentSetId } }, componentSets: { nodeId: { name, key } } }` |
| `GET /v1/files/{key}?depth=1` | Lightweight metadata (lastModified check) | `{ lastModified, components, componentSets }` |
| `GET /v1/files/{key}/nodes?ids=X,Y` | Specific node subtrees | `{ nodes: { nodeId: { document: {...} } } }` |
| `GET /v1/images/{key}?ids=X,Y&format=svg` | SVG export URLs | `{ images: { nodeId: "https://..." } }` |
| `GET /v1/images/{key}?ids=X,Y&format=png&scale=2` | PNG export URLs | `{ images: { nodeId: "https://..." } }` |

### Rate Limits & Batching

- Image export: batch up to 100 node IDs per request
- Content download: max 10 parallel threads per batch
- Retry: 3 attempts with exponential backoff (0.5s, 1s, 1.5s)
- Timeouts: API calls 30s open / 300s read; content download 10s open / 30s read

### Key Figma JSON Node Properties

```json
{
  "id": "51108:11396",
  "type": "COMPONENT_SET | COMPONENT | FRAME | GROUP | INSTANCE | TEXT | VECTOR | RECTANGLE | ELLIPSE | ...",
  "name": "Button",
  "children": [...],
  "componentId": "45081:496944",           // INSTANCE only: which component this is an instance of
  "componentPropertyDefinitions": {         // On COMPONENT/COMPONENT_SET
    "Label#43750:0": { "type": "BOOLEAN", "defaultValue": true },
    "Content#43761:6": { "type": "TEXT", "defaultValue": "Content" },
    "↳ Start icon#2:0": { "type": "INSTANCE_SWAP", "defaultValue": "45081:496660", "preferredValues": [...] },
    "Size": { "type": "VARIANT", "defaultValue": "M" }
  },
  "componentPropertyReferences": {          // On child nodes: which prop controls this node
    "visible": "Label#43750:0",
    "characters": "Content#43761:6",
    "mainComponent": "↳ Start icon#2:0"
  },
  "componentProperties": {                  // On INSTANCE: override values
    "Size": { "type": "VARIANT", "value": "M" },
    "↳ Start icon#2:0": { "type": "INSTANCE_SWAP", "value": "45081:496660" }
  },
  "fills": [{ "type": "SOLID|IMAGE|GRADIENT_LINEAR|...", "color": {...}, "visible": true }],
  "strokes": [...],
  "effects": [{ "type": "DROP_SHADOW|INNER_SHADOW|LAYER_BLUR|BACKGROUND_BLUR", ... }],
  "absoluteBoundingBox": { "x": 0, "y": 0, "width": 100, "height": 50 },
  "layoutMode": "HORIZONTAL|VERTICAL",     // Auto-layout direction
  "primaryAxisAlignItems": "MIN|CENTER|MAX|SPACE_BETWEEN",
  "counterAxisAlignItems": "MIN|CENTER|MAX|BASELINE",
  "primaryAxisSizingMode": "FIXED|AUTO",
  "counterAxisSizingMode": "FIXED|AUTO",
  "layoutGrow": 0|1,
  "itemSpacing": 8,
  "paddingTop/Right/Bottom/Left": 16,
  "cornerRadius": 8,
  "clipsContent": true,
  "visible": true,
  "opacity": 1.0,
  "slots": [{ "name": "content", "preferredValues": [{ "type": "COMPONENT_SET", "key": "abc123" }] }]
}
```

---

## 3. Import Pipeline

### Step 0: Sync Trigger (`DesignSystemSyncJob`)

1. For each FigmaFile in the DS at the new version:
   - Lightweight API call (`?depth=1`) to check `lastModified`
   - If unchanged: copy all data from previous version (components, variants, assets)
   - If changed: enqueue `FigmaFileImportJob`
2. Estimate memory: `200 MB + (component_count × 0.8 MB)` → select Heroku dyno size
3. Concurrency guard: one sync per design_system_id at a time

### Step 1: Import (`Figma::Importer`)

**Input:** FigmaFile record with `figma_file_key`
**Output:** ComponentSet, ComponentVariant, Component records with raw `figma_json`

Algorithm:
1. Fetch full file: `GET /v1/files/{key}`
2. Store `component_key_map`: `{ node_id → component_key }` for ALL components in file metadata (enables cross-file resolution later)
3. Collect components from metadata:
   - `file["componentSets"]` → ComponentSet records
   - `file["components"]` → either Variant (if has `componentSetId`) or standalone Component
4. Build node index: recursive walk of `document.children`, index every node by `id`
5. Enrich each component with:
   - Full `figma_json` from node index
   - `prop_definitions`: cleaned from `componentPropertyDefinitions` (strip `#nodeId` suffixes)
   - `slots`: from Figma Slots API or INSTANCE_SWAP `preferredValues`
   - `is_root`: `#root` in name or description
   - `is_image`: `#image` in name or description
   - `content_hash`: SHA256 of figma_json + prop_definitions + slots (first 16 hex chars)
6. Filter empty components:
   - A component is "empty" if all its visual nodes have no fills and no strokes
   - INSTANCE nodes are never empty (they reference other components)
   - `#image` components are kept even if empty (intentional placeholders)
7. Persist via upsert (unique by `[figma_file_id, node_id]`)

### Step 2: Asset Extraction (`Figma::AssetExtractor`)

**Input:** FigmaFile with populated components
**Output:** FigmaAsset records (SVG and PNG)

Three extraction passes:

**Pass A — Component-level SVGs:**
- For component sets/components where `vector?` is true (all children are vector types)
- Export default variant as SVG via Figma image API
- Store as FigmaAsset with `component_set_id` or `component_id`

**Pass B — Inline vector frames:**
- Walk all variant/component `figma_json` trees
- Identify frames where ALL children are vector types AND at least one is a "complex" vector (VECTOR, BOOLEAN_OPERATION, STAR, POLYGON)
- Skip trivial shapes (frames containing only RECTANGLE, ELLIPSE, or LINE — CSS handles these)
- For INSTANCE nodes: also check for IMAGE fills → route to PNG path
- **Deduplication by componentId:** group INSTANCE nodes by `componentId`, export one representative, copy SVG to all siblings
- Export as SVG, store as FigmaAsset with `component_id: nil, component_set_id: nil` (keyed by `node_id`)

**Pass C — Inline raster images:**
- Nodes with `fills` containing `{ "type": "IMAGE" }` → export as PNG at 2x scale
- Same componentId deduplication as above
- Store as FigmaAsset with `asset_type: "png"`, content is Base64-encoded

### Step 3: Code Generation (`Figma::ReactFactory`)

**Input:** FigmaFile with components + assets
**Output:** `react_code` (JSX source) and `react_code_compiled` (browser-ready JS) on each variant/component

#### Phase 1: Build Lookup Tables

Index ALL components across ALL sibling FigmaFiles in the same DesignSystem:
- `components_by_node_id`: standalone components
- `component_sets_by_node_id`: component sets
- `variants_by_node_id`: all variants
- `variants_by_component_key`: for cross-file resolution
- `component_key_by_node_id`: from the current file's `component_key_map`

Also load:
- SVG asset cache (by normalized component name)
- Inline SVG cache (by node_id)
- Inline PNG cache (by node_id)

#### Phase 2: Generate Each Component

For each component set, choose path based on type:

**SVG Component** (has SVG asset by name):
```jsx
const svg = `<svg ...>...</svg>`;
export function ChevronDown(props) {
  return <div data-component="ChevronDown" style={{ width: '16px', height: '16px', flexShrink: 0 }} dangerouslySetInnerHTML={{__html: svg}} {...props} />;
}
```
Width/height extracted from SVG attributes.

**Image Component** (`is_image: true`):
```jsx
export function ImagePlaceholder(props) {
  return <div data-component="ImagePlaceholder" style={{backgroundImage: `url(...)`, backgroundSize: 'cover'}} {...props} />;
}
```

**Multi-variant Component** (has VARIANT props + multiple variants):
- Generate a dispatcher function that checks variant prop values
- Each variant compiled separately with scoped CSS class names
- Dispatcher selects the right variant function at runtime

**Single-variant / Standard Component:**
1. Extract props from `prop_definitions`:
   - VARIANT → string enum prop
   - TEXT → string prop with default value
   - BOOLEAN → boolean prop with default
   - INSTANCE_SWAP (with preferredValues) → slot
   - INSTANCE_SWAP (without preferredValues) → component reference prop (`XxxComponent = DefaultIcon`)
2. Build slot map from Figma Slots + INSTANCE_SWAP
3. Recursively generate JSX from `figma_json` tree via `generate_node()`
4. Collect CSS rules into a `<style>` tag
5. Wrap in component function with props destructuring

#### Node-to-JSX Transformation Rules

| Figma Type | JSX Output | CSS |
|------------|-----------|-----|
| FRAME, GROUP, COMPONENT | `<div className="x">children</div>` | Auto-layout → flexbox; absolute positioning for non-auto-layout |
| TEXT | `<span className="x">text</span>` | Font properties; if bound to TEXT prop: `{propName}` |
| RECTANGLE, ELLIPSE, LINE, etc. | `<div className="x" />` | Dimensions, fills, strokes; ELLIPSE gets border-radius: 50% |
| INSTANCE (resolved) | `<ComponentName propOverrides />` | Inherit from component definition |
| INSTANCE (unresolved) | `<div style={{background: '#FF69B4'}} title="Missing: X" />` | Pink placeholder |
| INSTANCE (INSTANCE_SWAP, with preferredValues) | `{props.slotName}` | Slot content |
| INSTANCE (INSTANCE_SWAP, no preferredValues) | `{SwapComponent && <SwapComponent />}` | Dynamic icon prop |
| SLOT | `<div className="x">{props.slotName}</div>` | Layout constraints, min-width: 0 if flex-grow |
| Vector frame (inline SVG cached) | `<div dangerouslySetInnerHTML={{__html: svg}} />` | Size from parent |
| Image fill node (inline PNG cached) | `<img src="data:image/png;base64,..." />` | Size from CSS |

#### INSTANCE Resolution Order

1. Check `components_by_node_id[componentId]` (same-file standalone)
2. Check `component_sets_by_node_id[componentId]` (same-file set)
3. Check `variants_by_node_id[componentId]` (same-file variant)
4. **Cross-file:** `component_key_by_node_id[componentId]` → `variants_by_component_key[key]`
5. If all fail → pink placeholder + validation warning on parent component

#### INSTANCE_SWAP Override Resolution

When a parent component uses a child component and overrides its INSTANCE_SWAP prop:
- The child's `componentProperties` contains the overridden `componentId` value
- Resolve this value through the same 4-step resolution chain
- Pass as `XxxComponent={ResolvedComponent}` (component reference, not rendered element)

#### Compilation

- JSX → compiled JS via esbuild (`--loader=jsx --jsx=transform --target=es2020`)
- Batch compilation: write all files to temp dir, invoke esbuild once
- Fallback: compile individually if batch fails
- Output: browser-ready code using `React.createElement()`

### Step 4: Visual Diff (`VisualDiffJob`)

- Screenshot each component via headless Chromium
- Compare pixel-by-pixel to Figma-exported PNG
- Store diff percentage and diff image path on component_set/component

---

## 4. Rendering

### Renderer Endpoint

`GET /api/iterations/:id/renderer` → HTML page

1. Determine which FigmaFiles to load (from iteration's design_system_id + version)
2. Extract component names from iteration JSX (`<ComponentName` pattern)
3. Load compiled code for each referenced component:
   - Per-variant loading: match JSX prop values to variant props, generate dispatcher
   - Fallback: load full blob from default variant
4. **Transitive dependency resolution:** scan loaded code for:
   - `React.createElement(X)` calls
   - `Component: X` prop values
   - `Component = X` default values
   - Iteratively load referenced components until no new refs found
5. Output HTML document with:
   - React 18 UMD from CDN
   - Babel standalone (async) for live JSX editing
   - Each component in its own `<script>` tag (isolated error handling)
   - Slot wrapper logic: extracts `<Slot name="x">children</Slot>` from JSX children
   - Container wrapper: multi-slot component support
   - PostMessage handler: receives JSX from parent window, renders via Babel

### Rendering Flow in Browser

```
Parent window (DesignView.vue)
  → postMessage({ jsx: "<Page>...</Page>" })
    → iframe receives message
      → Babel.transform(jsx) → compiled JS
        → eval() → React element
          → ReactDOM.render(element, root)
            → Each component's compiled code executes
              → React renders to DOM
```

---

## 5. AI Generation Pipeline

### Schema Generation (`DesignGenerator`)

1. Collect root components (`is_root: true`) from current FigmaFiles
2. Build reachability graph: from roots, follow slot `allowed_children` references
3. For each reachable component, build JSON Schema definition:
   - Required VARIANT props → enum
   - Required TEXT props → string with default
   - BOOLEAN props → boolean with default
   - INSTANCE_SWAP (image) → string (AI provides search query text)
   - Slots → array of `$ref` to allowed children
4. Top-level schema: `AllComponents` as `anyOf` referencing root component defs

### Generation Flow

1. User enters prompt
2. Backend builds JSON Schema from design system
3. Send prompt + schema to AI model (OpenAI structured output)
4. AI returns JSON tree matching schema
5. `JsonToJsx` converts JSON tree to JSX string:
   - Separate slot props (arrays of child components) from regular props
   - Wrap slot content in `<Slot name="x">` tags
   - Handle boolean, string, expression props
6. Store JSX on Iteration record
7. Frontend sends JSX to renderer iframe via postMessage

---

## 6. Performance Characteristics

### Import Duration (typical)

| Step | Duration | Bottleneck |
|------|----------|-----------|
| Figma API fetch (full file) | 3-10s | Network, file size |
| Import (parse + persist) | 5-30s | DB writes, component count |
| SVG asset extraction | 30-300s | Figma image API rate limit, download parallelism |
| PNG asset extraction | 10-60s | Same as above |
| Code generation | 30-120s | esbuild compilation, component count |
| Visual diff | 30-60s | Headless browser screenshots |

### Optimizations Implemented

- **Incremental sync:** skip unchanged files via `lastModified`
- **Content hash:** skip codegen for unchanged components
- **SVG deduplication:** group INSTANCE nodes by componentId, export once
- **Trivial shape filtering:** skip SVG export for simple RECTANGLE/ELLIPSE/LINE
- **Batch compilation:** single esbuild invocation for all components
- **Per-variant loading:** renderer only loads variants actually used in JSX

---

## 7. Testing Strategy

The pipeline has two sources of ground truth: the **Figma API response** (input) and the **Figma screenshot** (expected output). Everything in between is our code. Tests anchor against these truths at five layers.

### Layer 1 — Import Integrity (Figma JSON → DB)

**What:** Verify the importer produces the correct DB records from a known Figma API response.

**How:**
- Freeze a real Figma API response as a JSON fixture (`spec/fixtures/figma/`)
- Stub `Figma::Client` to return the fixture
- Run `Importer.import`
- Assert: component_set count, component count, variant count
- Assert: each component's prop_definitions, slots, is_root, is_image, node_id
- Assert: component_key_map stored on FigmaFile
- Assert: re-import is idempotent (no duplicates)

**Catches:** Importer regressions — changed parsing, broken slot detection, lost props.

**Speed:** Fast (no network, no browser). Runs in RSpec.

### Layer 2 — Codegen Structural Checks (DB → JSX)

**What:** Verify generated React code is structurally correct without rendering.

**How:**
- Import from fixture (Layer 1)
- Run `ReactFactory.generate_all`
- For each component, assert:
  - `react_code` is non-empty
  - esbuild compilation succeeds (no syntax errors)
  - Compiled code contains `data-component="ComponentName"`
  - Compiled code does NOT contain `#FF69B4` (pink placeholder) when all deps are present
  - INSTANCE_SWAP props produce `XxxComponent` parameter in function signature
  - SVG components have `width` and `height` in style
  - Cross-file references resolve (no "undefined" in compiled output)
- For components WITH expected unresolved deps:
  - Assert pink placeholder IS present
  - Assert validation_warnings is non-empty

**Catches:** Code generation regressions — broken prop handling, missing cross-file resolution, SVG sizing.

**Speed:** Medium (needs esbuild). Runs in RSpec.

### Layer 3 — Render Integrity (JSX → Browser)

**What:** Verify each component renders in a real browser without errors.

**How:**
- Start renderer server
- For each component, render via `ReactDOM.render(React.createElement(ComponentName), root)`
- Assert: zero `console.error` / `pageerror` events
- Assert: DOM element with `data-component` exists
- Assert: element has non-zero width and height
- Record: element dimensions for regression tracking

**Catches:** Runtime errors — missing dependencies, undefined references, CSS that collapses layout.

**Speed:** Slow (headless browser). Runs as Rake task or separate test suite.

### Layer 4 — Visual Fidelity (our render vs Figma render)

**What:** Pixel-level comparison of each component against Figma's own render. This is the ultimate test — if it passes, everything works.

**How:**
1. Export each component's default variant as PNG from Figma API (1x scale)
2. Render same component in headless Chromium, screenshot the `[data-component]` element
3. Pixel diff: compare each pixel, threshold 30 per RGB channel
4. Score: count of diff pixels
5. Save report: `{ component_name, figma_size, render_size, diff_pixels, diff_percent }`

**Targets:**
- Per-component: < 100 diff pixels (font rendering tolerance)
- Whole-page composition: < 200 diff pixels
- Zero structural diffs (wrong position, missing elements, wrong color)

**Frozen Fixtures:**
- Save Figma PNGs as frozen fixtures in `spec/fixtures/figma_screenshots/`
- Compare against frozen fixtures in CI (no Figma API needed)
- Refresh fixtures manually when Figma file is updated

**Catches:** Everything — wrong CSS, missing icons, broken layout, bad sizing, font issues, SVG problems. Any visual regression.

**Speed:** Slow (headless browser + image comparison). Runs as separate suite.

### Layer 5 — AI Round-trip (prompt → JSX → render)

**What:** Verify the AI generation pipeline produces renderable output.

**How:**
- Given a fixed design system + fixed prompt
- Build JSON Schema via `DesignGenerator`
- Validate schema structure (has root components, has $refs)
- Given a fixed AI response (frozen fixture), convert via `JsonToJsx`
- Assert: JSX parses without errors
- Assert: all referenced components exist in the DS
- Render in browser:
  - Zero console errors
  - Non-empty visual output (screenshot is not blank)

**Catches:** Schema generation bugs, JSX conversion bugs, missing component references.

**Speed:** Medium (no AI call if using fixture). Runs in RSpec + headless browser.

---

## 8. Quality Metrics & Scoring

### Visual Fidelity (Priority 0)

**Target: < 100px diff per component**

Report format (saved to `tmp/visual_regression_report.json`):
```json
{
  "timestamp": "2026-03-23T18:00:00Z",
  "design_system": "WM",
  "components": [
    { "name": "Select", "diff_pixels": 42, "figma_size": "340x40", "render_size": "340x40", "status": "pass" },
    { "name": "Button", "diff_pixels": 15, "figma_size": "200x40", "render_size": "200x40", "status": "pass" }
  ],
  "summary": { "total": 156, "pass": 150, "fail": 6, "avg_diff": 28 }
}
```

### Import Duration (Priority 1)

**Target: track and prevent regression**

Report format (saved to `tmp/import_benchmark.json`):
```json
{
  "timestamp": "2026-03-23T18:00:00Z",
  "file_key": "oL5zKzFeTuZRd2rFMbUJWa",
  "steps": {
    "api_fetch_ms": 4200,
    "import_ms": 12000,
    "asset_extraction_ms": 45000,
    "codegen_ms": 62000,
    "total_ms": 123200
  },
  "counts": { "component_sets": 109, "components": 47, "svg_assets": 1840, "png_assets": 272 }
}
```

### Render Duration (Priority 2)

**Target: track and prevent regression**

Report format (saved to `tmp/render_benchmark.json`):
```json
{
  "timestamp": "2026-03-23T18:00:00Z",
  "renderer_load_ms": 1200,
  "component_count": 156,
  "total_script_bytes": 2400000,
  "components": [
    { "name": "Select", "compile_ms": 5, "render_ms": 12 }
  ]
}
```
