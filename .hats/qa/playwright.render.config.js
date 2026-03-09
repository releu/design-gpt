import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Render config: runs component-by-component rendering validation.
// Requires Figma import (long timeout). Reuses existing DB by default.
const testDir = defineBddConfig({
  featuresRoot: "../shared/specs",
  features: "../shared/specs/10-complex-figma-compatibility.feature",
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen",
});

export default defineConfig({
  testDir,
  timeout: 1_200_000,
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

  globalSetup: "./global-setup-render.js",

  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
