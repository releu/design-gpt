import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// 02-health-check.feature
// ---------------------------------------------------------------------------

// Scenario: API health endpoint responds

When("the API health endpoint is checked", async ({ request, world }) => {
  world.healthResponse = await request.get("/api/up");
});

Then("the API should report that it is running", async ({ world }) => {
  expect(world.healthResponse.status()).toBe(200);
});

// Scenario: Frontend loads through the proxy

When(
  "a user navigates to the application URL",
  async ({ page, world }) => {
    const res = await page.goto("/");
    world.frontendResponse = res;
  },
);

Then("the frontend page loads successfully", async ({ world }) => {
  expect(world.frontendResponse.status()).toBe(200);
});

Then("the application container is present", async ({ page }) => {
  await expect(page.locator("#app")).toBeAttached({ timeout: 10_000 });
});
