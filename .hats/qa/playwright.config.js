import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

const testDir = defineBddConfig({
  features: "./features/**/*.feature",
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
        "cd ../developer/api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails server -p 3000 -b 127.0.0.1",
      port: 3000,
      reuseExistingServer: true,
      timeout: 30_000,
    },
    {
      command: "cd ../developer/app && VITE_E2E_TEST=true npm run dev",
      port: 5173,
      reuseExistingServer: true,
      timeout: 15_000,
    },
    {
      command: "cd ../developer/caddy && caddy run --config Caddyfile",
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
