import path from "path";
import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Background: application running
// ---------------------------------------------------------------------------

Given("the application is running", async ({ request }) => {
  const res = await request.get("/api/up");
  expect(res.status()).toBe(200);
});

// ---------------------------------------------------------------------------
// Background: logged-in user
// ---------------------------------------------------------------------------

Given(
  "the user is logged in as {string}",
  async ({ page, world }, email) => {
    world.authToken = createTestToken({ email });
    await page.goto(`/?e2e_token=${world.authToken}`);
    await expect(page.locator('[qa="app"]')).toBeVisible({ timeout: 15_000 });
  },
);

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

Given("the user is on the home page", async ({ page }) => {
  await expect(page.locator('[qa="app"]')).toBeVisible({ timeout: 10_000 });
});

When("the user visits the home page", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator('[qa="app"]')).toBeVisible({ timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Screenshots
// ---------------------------------------------------------------------------

When("I take a screenshot {string}", async ({ page }, name) => {
  const dir = path.resolve(import.meta.dirname, "../screenshots");
  await page.screenshot({
    path: path.join(dir, `${name}.png`),
    fullPage: true,
  });
});

// ---------------------------------------------------------------------------
// Console errors
// ---------------------------------------------------------------------------

Then(
  "there are no console errors",
  async ({ consoleErrors, requestFailures }) => {
    expect(requestFailures).toEqual([]);
    expect(consoleErrors).toEqual([]);
  },
);
