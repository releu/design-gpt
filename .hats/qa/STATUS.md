# QA Status

Last update: 2026-03-17 — step definitions updated for spec overhaul + validation warnings + shared links + figma export

## Test Suites

| Suite | Config | Features | Mode |
|-------|--------|----------|------|
| fast | playwright.fast.config.js | 01-02 | Quick regression |
| workflow | playwright.workflow.config.js | 03-09, 11-12 | Full workflow |
| render | playwright.render.config.js | 10 | Component compatibility |
| debug | playwright.debug.config.js | configurable | Headed browser, slow motion |
| all | playwright.config.js | all | Everything |

## Debug Mode

Run with visible browser for step-by-step debugging:

```bash
bash run-tests.sh debug                    # all workflow features
FEATURE=03 bash run-tests.sh debug         # single feature file
FEATURE=08 bash run-tests.sh debug         # component browser only
```

## Changes in this update

### New step files
- `figma-export.steps.js` — covers 12-figma-export.feature (share code, plugin rendering, error handling)

### Updated step files
- `figma-import.steps.js` — fixed stale `"Page #root"` step → `"#root" in description`. Added IMAGE component steps + all general validation warning steps (glass, overflow, skew, scroll, fixed-position)
- `design-system.steps.js` — added public DS (admin-only), versioning, sync queue steps
- `design-generation.steps.js` — added validation warnings in AI schema, IMAGE components in generation
- `component-browser.steps.js` — added validation warning indicators, no-root warning, IMAGE indicator steps
- `design-management.steps.js` — added shared design link steps (share code, public access, exports)
- `image-workflow.steps.js` — rewritten from raw test format to BDD steps

### Config changes
- `playwright.workflow.config.js` — added 11-image-workflow.feature and 12-figma-export.feature
- `playwright.debug.config.js` — new config for headed browser with slowMo + FEATURE env var
- `run-tests.sh` — added `debug` mode
- `package.json` — added `test:debug` script

## Scenario count (113 total)

| Feature | Scenarios |
|---------|-----------|
| 01 Authentication | 6 |
| 02 Health Check | 2 |
| 03 Figma Import | 28 |
| 04 DS Management | 10 |
| 05 Design Generation | 14 |
| 06 Design Improvement | 11 |
| 07 Design Management | 12 |
| 08 Component Browser | 17 |
| 09 Visual Diff | 5 |
| 10 Figma Compatibility | 3 |
| 11 Image Workflow | 8 |
| 12 Figma Export | 4 |

## Next: run debug mode together to verify step-by-step
