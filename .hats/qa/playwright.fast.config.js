import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Fast config: only runs features that do NOT require Figma import.
// Suitable for quick regression checks during development.
const testDir = defineBddConfig({
  features: [
    "./features/01-health-check.feature",
    "./features/02-authentication.feature",
    "./features/03-api-design-management.feature",
    "./features/04-api-figma-import.feature",
    "./features/05-api-custom-components.feature",
    "./features/06-api-visual-diff.feature",
    "./features/07-api-svg-assets.feature",
    "./features/08-api-figma-json.feature",
    "./features/09-api-ai-pipeline.feature",
    "./features/10-api-image-search.feature",
    "./features/18-onboarding-wizard.feature",
    "./features/19-ui-layout-design-system.feature",
  ],
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen",
});

export default defineConfig({
  testDir,
  timeout: 30_000,
  retries: 0,
  use: {
    baseURL: "https://design-gpt.localtest.me",
    ignoreHTTPSErrors: true,
  },

  webServer: [
    {
      command:
        "cd ../../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails server -p 3000 -b 127.0.0.1",
      port: 3000,
      reuseExistingServer: true,
      timeout: 30_000,
    },
    {
      command: "cd ../../app && VITE_E2E_TEST=true npm run dev",
      port: 5173,
      reuseExistingServer: true,
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
