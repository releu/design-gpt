# Image Workflow — QA Testing Guide

## RSpec (unit/integration)

Run all image-related specs:

```bash
cd api && bundle exec rspec \
  spec/services/yandex_images_spec.rb \
  spec/models/image_cache_spec.rb \
  spec/requests/images_spec.rb \
  spec/services/figma/react_factory_image_spec.rb \
  spec/services/exports/figma_tree_builder_image_spec.rb
```

### What each spec covers

| Spec | Tests |
|------|-------|
| `yandex_images_spec` | Yandex API call, URL param rewriting (n=33, w=1200, h=1200), error handling |
| `image_cache_spec` | Cache miss → creates record, cache hit → no API call, query normalization, race condition |
| `images_spec` | Endpoint returns proxied image bytes + CORS headers, 400 for blank, 404 on error, auth on search |
| `react_factory_image_spec` | `#image` component → `<div>` + backgroundSize, INSTANCE_SWAP → `<div>` + backgroundImage |
| `figma_tree_builder_image_spec` | `isImage: true` flag, image INSTANCE_SWAP in textProperties |

## Manual testing in Figma

### Prerequisites

1. A Figma file with:
   - A component with `#image` in its description (e.g. `RandomImage`)
   - A component that uses it via INSTANCE_SWAP (e.g. `Block / SuperAds`)
   - A root component (`#root`) with a slot that can contain the above
2. The design system imported in DesignGPT
3. `YANDEX_SEARCH_API_KEY` set in the Rails `.env`

### Test steps

1. **Import the Figma file** — verify the `#image` component appears with `is_image: true`:
   ```ruby
   rails runner 'FigmaFile.last.components.where(is_image: true).pluck(:name)'
   ```

2. **Create a design** with a tree that includes the image component:
   ```ruby
   # The tree should include the image prompt as a camelCase prop
   tree = {
     "component" => "RootComponent",
     "children" => [{
       "component" => "CardWithImage",
       "imageinstance" => "sunset over mountains"
     }]
   }
   ```

3. **Verify the web preview** renders `<div>` with `backgroundImage`, not `<img>`:
   - Open the design preview in the browser
   - Inspect the image area — should be a `<div>` with `background-image: url(...)`, `background-size: cover`
   - No `<img>` tags for image components

4. **Test the image endpoint** directly:
   ```bash
   curl -s "https://design-gpt.localtest.me/api/images/render?prompt=sunset" \
     -w "\nHTTP: %{http_code}\nContent-Type: %{content_type}" -o /dev/null
   # Should return: HTTP: 200, Content-Type: image/jpeg
   ```

5. **Export to Figma** via the plugin:
   - Open the Figma plugin, enter the share code
   - Click Import
   - The generated frame should show the image component with an IMAGE fill (not yellow/solid)
   - Text props (title, subtitle, etc.) should be set correctly

6. **Dev loop testing** (for developers):
   ```bash
   # Start dev loop
   cd figma-dev-loop && node server.js

   # Trigger render
   curl -X POST https://design-gpt.localtest.me/dev-loop/trigger \
     -H "Content-Type: application/json" -d '{"action": "run"}'

   # Check result
   curl https://design-gpt.localtest.me/dev-loop/result
   # Look for: [image] Posting fetch-images with N fills
   ```

### What to verify in Figma

- The `#image` component instance should have **IMAGE** fill type (not SOLID)
- The image should match the prompt (e.g. "modern apartment building" → photo of a building)
- Text properties (title, subtitle, meta) should be set correctly
- The component structure should be intact (no broken layers)

### Common failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Yellow/solid fill | Image fetch failed in plugin | Check CORS headers, verify `/api/images/render` returns 200 |
| No image component in DB | Component not published or `#image` tag missing | Add `#image` to name or description in Figma |
| `is_image` column missing | Migration not run | `bundle exec rails db:migrate` |
| "YANDEX_SEARCH_API_KEY not found" | Env var missing | Add to `.env` file |
| Image endpoint returns 404 | Yandex API error or cache miss + API failure | Check API key, check Rails logs |
| Node not found in plugin | detachInstance changed IDs | Name-based fallback should handle this; check plugin console logs |

## E2E (Playwright)

```bash
.hats/qa/run-tests.sh
```

Tests are in `.hats/qa/steps/image-workflow.steps.js`. Requires E2E seed data (`bundle exec rake e2e:seed`).
