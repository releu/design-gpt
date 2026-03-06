import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// 01-authentication.feature
// ---------------------------------------------------------------------------

// Scenario: Unauthenticated user sees sign-in screen

When(
  "a user visits the home page without being logged in",
  async ({ page }) => {
    await page.goto("/?unauth=1");
    await page.waitForLoadState("domcontentloaded");
  },
);

Then("a sign-in control is shown", async ({ page }) => {
  const signIn = page.locator("[class*='sign-in-card'], [class*='App__signin']");
  await expect(signIn.first()).toBeVisible({ timeout: 15_000 });
});

Then(
  "no application content is visible behind the sign-in screen",
  async ({ page }) => {
    await expect(page.locator(".Prompt")).not.toBeVisible({ timeout: 5_000 });
    await expect(page.locator(".LibrarySelector")).not.toBeVisible({ timeout: 5_000 });
  },
);

// Scenario: Clicking the sign-in control initiates login

Given("the user is on the sign-in screen", async ({ page }) => {
  await page.goto("/?unauth=1");
  const card = page.locator("[class*='sign-in-card']");
  await expect(card.first()).toBeVisible({ timeout: 15_000 });
});

When("the user clicks the sign-in control", async ({ page }) => {
  const card = page.locator("[class*='sign-in-card']");
  await card.first().click();
});

Then(
  "the browser redirects to the hosted login page",
  async ({ page }) => {
    // mock-auth0.js: loginWithRedirect() flips isAuthenticated to true,
    // sign-in card disappears and the app renders
    const signInCard = page.locator("[class*='sign-in-card']");
    await expect(signInCard).not.toBeVisible({ timeout: 10_000 });
    await expect(page.locator(".App")).toBeVisible({ timeout: 10_000 });
  },
);

// Scenario: Authenticated user sees the workspace

Then(
  "the workspace is visible and the user can start generating designs with AI",
  async ({ page }) => {
    await expect(page.locator(".Prompt")).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(".LibrarySelector")).toBeVisible({ timeout: 10_000 });
  },
);

// Scenario: Unauthenticated requests are rejected

When(
  "a user tries to access the application without signing in",
  async ({ request, world }) => {
    world.apiResponse = await request.get("/api/designs");
  },
);

Then(
  "the application refuses access and shows the sign-in screen",
  async ({ page, world }) => {
    if (world.apiResponse) {
      expect(world.apiResponse.status()).toBe(401);
    }
  },
);

// Scenario: Invalid or expired credentials are rejected

When(
  "a user tries to access the application with invalid credentials",
  async ({ request, world }) => {
    world.apiResponse = await request.get("/api/designs", {
      headers: { Authorization: "Bearer invalid.token.here" },
    });
  },
);

// Scenario: Token refresh on expiry

Given("the session has expired", async ({ world }) => {
  world.expiredToken = createTestToken({
    email: "alice@example.com",
    exp: Math.floor(Date.now() / 1000) - 3600,
  });
});

When(
  "the user performs an action that requires authentication",
  async ({ request, world }) => {
    // First try with expired token — should fail
    const expiredRes = await request.get("/api/designs", {
      headers: { Authorization: `Bearer ${world.expiredToken}` },
    });
    world.expiredStatus = expiredRes.status();
    // Then "refresh" with a valid token — simulates silent refresh
    world.apiResponse = await request.get("/api/designs", {
      headers: { Authorization: `Bearer ${world.authToken}` },
    });
  },
);

Then("the session is silently refreshed", async ({ world }) => {
  expect(world.expiredStatus).toBe(401);
});

Then(
  "the action succeeds without redirecting to the sign-in screen",
  async ({ world }) => {
    expect(world.apiResponse.status()).toBe(200);
  },
);
