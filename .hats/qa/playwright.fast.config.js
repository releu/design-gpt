import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Fast config: only runs features that do NOT require Figma import.
// Suitable for quick regression checks during development.
const testDir = defineBddConfig({
  featuresRoot: "../shared/specs",
  features: [
    "../shared/specs/01-authentication.feature",
    "../shared/specs/02-health-check.feature",
  ],
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen-fast",
});

export default defineConfig({
  testDir,
  timeout: 30_000,
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
