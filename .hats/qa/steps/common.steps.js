import path from "path";
import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

Given("I navigate to the home page", async ({ page }) => {
  await page.goto("/");
});

Given("the app container is visible", async ({ page }) => {
  await expect(page.locator(".App")).toBeVisible({ timeout: 10_000 });
});

Then("the app container should be visible", async ({ page }) => {
  await expect(page.locator(".App")).toBeVisible({ timeout: 10_000 });
});

Then(
  "the page should contain the Vue app mount point",
  async ({ page }) => {
    await expect(page.locator("#app")).toBeAttached();
  },
);

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
