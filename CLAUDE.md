# Design-GPT

AI-assisted design generation tool. Users enter a prompt, the backend generates JSX code via AI, and a live preview renders it in an iframe using imported Figma component library components.

## Project Documentation

This project uses [Hats](https://github.com/anthropics/hats) for team coordination. Project documentation lives in `.hats/shared/`:

| File | Contents |
|------|----------|
| `stack.md` | Tech stack, project structure, conventions, design tokens, dependencies, design generation flow, Figma authoring conventions |
| `api.md` | API endpoint catalog, auth requirements, status flows, renderer protocol |
| `setup.md` | Prerequisites, installation, environment variables, dev servers, test suite organization, testing guidelines |

Feature specs: `.hats/manager/*.feature` (18 features)
Design descriptions: `.hats/designer/` (13 files)
E2E tests: `.hats/qa/` (19 features, 134 scenarios)

## Maintenance Rules

1. **Keep tests up to date**: When adding or modifying functionality, write or update corresponding tests (Vitest for frontend, RSpec for API). Run `make test` before considering work done.
2. **Keep docs current**: When project structure, conventions, or architecture change, update the relevant `.hats/shared/` file.
3. **Follow existing patterns**: Match the code style and conventions in each subdirectory. See `.hats/shared/stack.md` for details.
4. **E2E approach — real life, no shortcuts**: E2E tests (`.hats/qa/`) never mock API responses. Only auth is mocked. Tests start with a clean DB and create all data through the UI. The full Figma sync pipeline runs — no bypasses.
