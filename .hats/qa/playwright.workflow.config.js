import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Workflow config: runs full design workflow (import, generate, improve, export).
// Requires Figma import + OpenAI API. Long timeouts.
const testDir = defineBddConfig({
  features: [
    ".hats-manager/03-figma-import.feature",
    ".hats-manager/04-design-system-management.feature",
    ".hats-manager/05-design-generation.feature",
    ".hats-manager/06-design-improvement.feature",
    ".hats-manager/07-design-management.feature",
    ".hats-manager/08-component-library-browser.feature",
    ".hats-manager/09-visual-diff.feature",
  ],
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen-workflow",
});

export default defineConfig({
  testDir,
  timeout: 600_000,
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
