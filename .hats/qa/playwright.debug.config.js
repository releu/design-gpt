import { defineConfig } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

// Debug config: headed browser, slow motion, single worker.
// Run a specific feature file via FEATURE env var:
//   FEATURE=03 bash run-tests.sh debug
//   FEATURE=08 bash run-tests.sh debug
// Without FEATURE, runs all workflow features.
const featureNum = process.env.FEATURE;
const features = featureNum
  ? [`../shared/specs/${featureNum}*.feature`]
  : [
      "../shared/specs/03-figma-import.feature",
      "../shared/specs/04-design-system-management.feature",
      "../shared/specs/05-design-generation.feature",
      "../shared/specs/06-design-improvement.feature",
      "../shared/specs/07-design-management.feature",
      "../shared/specs/08-component-library-browser.feature",
      "../shared/specs/09-visual-diff.feature",
      "../shared/specs/11-image-workflow.feature",
      "../shared/specs/12-figma-export.feature",
    ];

const testDir = defineBddConfig({
  featuresRoot: "../shared/specs",
  features,
  steps: ["./steps/**/*.js", "./fixtures/test.js"],
  outputDir: "./.features-gen-debug",
});

export default defineConfig({
  testDir,
  timeout: 600_000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: "https://design-gpt-test.localtest.me",
    ignoreHTTPSErrors: true,
    headless: false,
    launchOptions: {
      slowMo: 300,
    },
    video: "retain-on-failure",
    trace: "retain-on-failure",
  },

  webServer: [
    {
      command:
        "cd ../../api && RAILS_ENV=test E2E_TEST_MODE=true bundle exec rails server -p 3001 -b 127.0.0.1",
      port: 3001,
      reuseExistingServer: true,
      timeout: 30_000,
    },
    {
      command: "cd ../../app && VITE_E2E_TEST=true npx vite --port 5174",
      port: 5174,
      reuseExistingServer: true,
      timeout: 15_000,
    },
    {
      command: "cd ../../caddy && caddy run --config Caddyfile",
      port: 443,
      reuseExistingServer: true,
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
