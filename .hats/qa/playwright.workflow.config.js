import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Workflow config: runs full design workflow (import, generate, improve, export).
// Requires Figma import + OpenAI API. Long timeouts.
const testDir = defineBddConfig({
  featuresRoot: "../shared/specs",
  features: [
    "../shared/specs/03-figma-import.feature",
    "../shared/specs/04-design-system-management.feature",
    "../shared/specs/05-design-generation.feature",
    "../shared/specs/06-design-improvement.feature",
    "../shared/specs/07-design-management.feature",
    "../shared/specs/08-component-library-browser.feature",
    "../shared/specs/09-visual-diff.feature",
  ],
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen-workflow",
});

export default defineConfig({
  testDir,
  timeout: 600_000,
  retries: 0,
  use: {
    baseURL: "https://design-gpt-test.localtest.me",
    ignoreHTTPSErrors: true,
  },

  webServer: [
    {
      command:
        "cd ../../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails server -p 3001 -b 127.0.0.1",
      port: 3001,
      reuseExistingServer: false,
      timeout: 30_000,
    },
    {
      command: "cd ../../app && VITE_E2E_TEST=true npx vite --port 5174",
      port: 5174,
      reuseExistingServer: false,
      timeout: 15_000,
    },
    {
      command: "cd ../../caddy && caddy run --config Caddyfile",
      port: 443,
      reuseExistingServer: !process.env.CI,
      timeout: 10_000,
    },
  ],

  globalSetup: "./global-setup.js",

  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
