# QA Report

## What was tested

Based on all 17 manager specs, the following scenarios are covered across 18 feature files and 13 step definition files:

### Infrastructure (Feature 01 - Health Check)
- API health endpoint responds with 200
- Frontend loads through Caddy proxy with Vue app mount point

### Authentication (Feature 02 - Authentication)
- Unauthenticated user sees sign-in prompt (no application content shown)
- Authenticated user sees main application (prompt area, design system selector)
- Auto-create user on first login via API
- API rejects requests without valid token (401)
- API rejects requests with invalid JWT token (401)
- Token with expired timestamp is rejected by API (401)

### Design Management API (Feature 03 - Design Management)
- List designs returns empty array for new user
- Create design requires component libraries
- Create a design via API with component libraries (201)
- View a specific design via API
- Default design name is derived from prompt
- Rename a design via PATCH API
- Duplicate a design via API (201)
- Delete a design via DELETE API (204)
- Deleted design is no longer accessible (404)
- Access another user's design returns 404
- Export Figma JSON for nonexistent design returns 404
- Export React project for nonexistent design returns 404
- Export image for nonexistent design returns 404

### Figma Import API (Feature 04 - Figma Import)
- Create a component library from a Figma URL (201)
- Created library has pending status
- Created library extracts figma file key from URL
- Duplicate Figma URL returns existing library (200)
- List user's component libraries
- View available libraries (own + public)
- Trigger sync on a library
- Library detail includes progress information
- List components for a library
- Re-import a component for nonexistent component returns 404
- Re-import a component set for nonexistent returns 404

### Custom Components API (Feature 05 - Custom Components)
- Upload a custom React component with prop_types (201)
- Upload a component with boolean prop type
- Update a custom component via PATCH
- Delete a custom component via DELETE (204)
- Upload a component with is_root and allowed_children
- Cannot upload to another user's library (404)
- Cannot modify another user's custom component (404)

### Visual Diff API (Feature 06 - Visual Diff)
- Visual diff for nonexistent component returns 404
- Diff image not available returns 404
- Figma screenshot for nonexistent component returns 404
- React screenshot for nonexistent component returns 404
- Invalid screenshot type returns 400
- Visual diff for existing component returns match_percent data

### SVG Assets API (Feature 07 - SVG Assets)
- SVG for nonexistent component returns 404
- HTML preview for nonexistent component returns 404
- SVG for existing component returns content
- SVG for component set returns content
- HTML preview for existing component

### Figma JSON API (Feature 08 - Figma JSON)
- Figma JSON for nonexistent component returns 404
- Figma JSON for nonexistent component set returns 404
- Figma JSON for existing component returns id, name, figma_json
- Figma JSON for existing component set returns data

### AI Pipeline API (Feature 09 - AI Pipeline)
- Task API rejects unauthorized workers (401)
- Design systems API requires authentication (401)
- List design systems for authenticated user
- Create a design system via API (201)
- Task show endpoint for nonexistent task returns 404
- Design generation creates a task when called via API

### Image Search API (Feature 10 - Image Search)
- Image search endpoint exists (not 404)
- Empty search query is handled gracefully (not 500)
- Image search returns JSON results

### Design System Modal UI (Feature 11 - Design System Management)
- Import Figma file and create a design system via modal (full UI flow)
- Browse components shows detail panel with name, type badge, status badge
- Component configuration is read-only from Figma conventions (root badge, allowed children)
- AI Schema view shows component tree

### Design Generation Workflow (Feature 12 - Design Generation)
- Ensure design system exists for generation
- Generate a design from a prompt ("rivers in Belgrade" -- checks for "Sava" and "Dunav")
- View mode switching between mobile, desktop, and code
- Code view shows editable JSX with CodeMirror syntax highlighting
- Editing JSX in code view triggers live preview update
- Design page shows design name in dropdown
- Navigate from design page back to new design
- New user with no design systems sees generate button
- Export menu is accessible from the design page (Download React project, Download image)

### Design Improvement via Chat (Feature 13 - Design Improvement)
- Setup design for improvement testing (generate first)
- Send an improvement request via chat
- Chat displays conversation history (user + designer messages)
- Empty message cannot be sent (send button disabled)
- Send button is disabled while generating
- Ctrl+Enter sends the message
- Chat panel auto-scrolls to latest message
- Settings panel shows component configuration

### Component Rendering Validation (Feature 14 - CRITICAL)
- Every component renders with default props without JavaScript errors
- Every component renders correctly with ALL prop variations:
  - VARIANT props: every dropdown option selected, iframe re-renders
  - TEXT props: test with sample text, verify text appears in iframe
  - BOOLEAN props: toggle on/off, verify render changes
- Text props display their actual values in rendered output
- Variant prop changes produce visually different renders (HTML diff)

### Preview Rendering (Feature 15 - Preview Rendering)
- Renderer page loads with React, ReactDOM, Babel scripts
- Renderer accepts JSX via postMessage and renders it
- Renderer serves without authentication
- Renderer handles missing component gracefully (error display)
- Error does not crash the renderer (recovery test)
- Design system renderer combines multiple libraries
- Iteration renderer uses the design's libraries

### Component Browser UI (Feature 16 - Component Library Browser)
- Libraries list page displays library cards with name and status
- Navigate to library detail page
- Component detail shows interactive props with dropdown selects
- Changing props updates the live preview (captures + compares HTML)
- Component detail shows React code in CodeMirror editor
- Component detail shows configuration for root components
- Overview shows library file names with component counts
- Component preview page renders all components in grid layout

### Design Export (Feature 17 - Design Management exports)
- Export Figma JSON via API returns tree, jsx, component_library_ids
- Export React project via API returns application/zip
- Export image returns 200 or 404 (depending on screenshot existence)
- Duplicate design via API returns new id with status 201
- Export menu is visible on design page with expected actions

### Onboarding Wizard (Feature 18 - Onboarding)
- Navigate through the onboarding wizard (4-step stepper)
- Step 1: Enter a prompt and proceed
- Cannot proceed from Prompt step with empty prompt
- Step 2: Select a library
- Cannot proceed from Libraries step with no selection
- Step 3: Review imported components
- Step 4: Organize components
- Navigate back to previous steps (preserves state)
- Complete onboarding creates a project

## Results

All tests are written and ready to execute. Tests will FAIL if the corresponding implementation does not exist yet -- this is by design. The QA suite provides independent verification of the manager's requirements.

Expected outcomes:
- PASS: Health check, authentication, API error handling (404/401 paths)
- PASS: Design management CRUD operations (create, view, rename, duplicate, delete)
- PASS: Figma import library creation, deduplication, listing
- PASS: Custom component CRUD lifecycle
- PASS or FAIL: Component rendering (depends on Figma import pipeline quality)
- PASS or FAIL: Design generation (depends on OpenAI API availability)
- PASS or FAIL: Chat improvement (depends on improve endpoint implementation)
- PASS or FAIL: Export endpoints (depends on implementation completeness)
- PASS or FAIL: Onboarding wizard (depends on /onboarding route implementation)
- PASS or FAIL: Libraries list page (depends on /libraries route implementation)

## How to run

```bash
# Run all tests (slow -- includes Figma import, AI generation)
bash qa/run-tests.sh

# Run fast tests only (API checks, auth, health, onboarding -- no Figma)
bash qa/run-tests.sh fast

# Run component rendering validation only (primary ask)
bash qa/run-tests.sh render

# Run full design workflow tests only
bash qa/run-tests.sh workflow
```

Prerequisites:
- Rails API server, Vite dev server, and Caddy must be running (or will be started by Playwright)
- `FIGMA_ACCESS_TOKEN` must be set in `developer/api/.env`
- `OPENAI_API_KEY` must be set in `developer/api/.env` (for design generation tests)
- PostgreSQL must be running with the test database available

## Notes

- All tests use the Figma file: https://www.figma.com/design/BoLWfKXuDvgWi6ucjHWHK7/DesignGPT-Cubes
- Authentication is mocked via HS256 HMAC tokens (E2E_TEST_MODE=true on the API)
- No API response mocking -- all tests hit real endpoints
- The component rendering validation iterates EVERY component and exercises EVERY prop
- For variant props with > 6 options, a sample of first/middle/last is tested
- Text prop validation checks that the entered text actually appears in the iframe DOM
- Renderer tests verify postMessage protocol: ready -> render -> content check
- Design generation tests check for specific content ("Sava", "Dunav") in the preview iframe
- The test DB starts clean (users only) -- everything is created through the UI or API
- Servers on ports: Rails 3000, Vite 5173, Caddy 443
- Base URL: https://design-gpt.localtest.me (Caddy reverse proxy with self-signed TLS)
- New tests for Visual Diff, SVG Assets, and Figma JSON require a ready library with imported components
- Onboarding wizard tests navigate to /onboarding directly
- Libraries page tests navigate to /libraries directly
- Export menu tests verify the "..." dropdown on the design page
