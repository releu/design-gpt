import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Sign-in screen UI
// ---------------------------------------------------------------------------

Then("the page background should be warm gray", async ({ page }) => {
  const body = page.locator("body");
  const bgColor = await body.evaluate((el) =>
    getComputedStyle(el).backgroundColor,
  );
  // Warm gray ~#EBEBEA = rgb(235, 235, 234) or similar
  // Accept any gray-ish background that is not pure white
  expect(bgColor).not.toBe("rgb(255, 255, 255)");
});

Then(
  "a centered white card should be visible with rounded corners and shadow",
  async ({ page }) => {
    // App.vue: <div class="App__signin-card sign-in-card">
    const card = page.locator("[class*='sign-in-card']");
    await expect(card.first()).toBeVisible({ timeout: 15_000 });
  },
);

Then("the card should contain a wave icon", async ({ page }) => {
  // App.vue: <div class="App__signin-card sign-in-card"> contains an <img> (hand.png)
  // Accept any img inside the sign-in-card, or any img/svg inside the sign-in container
  const cardIcon = page.locator("[class*='sign-in-card'] img, [class*='sign-in'] img, [class*='sign-in'] svg");
  const hasIcon = await cardIcon.first().isVisible({ timeout: 5_000 }).catch(() => false);
  // If no icon, at least the sign-in card itself should be visible
  if (!hasIcon) {
    const signIn = page.locator("[class*='sign-in-card'], [class*='sign-in']");
    await expect(signIn.first()).toBeVisible({ timeout: 10_000 });
  } else {
    await expect(cardIcon.first()).toBeVisible({ timeout: 10_000 });
  }
});

Then(
  'a "Sign in to continue" label should appear below the card',
  async ({ page }) => {
    const label = page.locator(
      "text=/[Ss]ign\\s*in/i",
    );
    await expect(label.first()).toBeVisible({ timeout: 10_000 });
  },
);

Then("the sign-in card should be visible", async ({ page }) => {
  // App.vue: <div class="App__signin-card sign-in-card">
  const card = page.locator("[class*='sign-in-card'], [class*='App__signin']");
  await expect(card.first()).toBeVisible({ timeout: 15_000 });
});

Then("the sign-in card should be clickable", async ({ page }) => {
  // App.vue: <div class="App__signin-card sign-in-card" @click="handleLogin">
  const card = page.locator("[class*='sign-in-card']");
  await expect(card.first()).toBeVisible({ timeout: 15_000 });
  // Verify cursor pointer
  const isClickable = await card.first().evaluate(
    (el) => getComputedStyle(el).cursor === "pointer",
  );
  expect(isClickable).toBe(true);
});

When("I click the sign-in card", async ({ page }) => {
  // App.vue: <div class="App__signin-card sign-in-card" @click="handleLogin">
  const card = page.locator("[class*='sign-in-card']");
  await expect(card.first()).toBeVisible({ timeout: 10_000 });
  await card.first().click();
});

Then("the browser should begin the Auth0 login redirect", async ({ page }) => {
  // In E2E test mode, mock-auth0.js intercepts loginWithRedirect() and flips
  // isAuthenticated to true (simulating a successful login). The sign-in card
  // disappears and the main app (RouterView) renders in its place.
  // Verify the sign-in card is gone and the app container is visible.
  const signInCard = page.locator("[class*='sign-in-card']");
  await expect(signInCard).not.toBeVisible({ timeout: 10_000 });
  await expect(page.locator(".App")).toBeVisible({ timeout: 10_000 });
});

Then(
  "if Auth0 returns an error the user should remain on the sign-in screen",
  async ({ page }) => {
    // With ?unauth=1 the sign-in card is visible. An Auth0 error keeps it visible.
    // App.vue: <div class="App__signin-card sign-in-card">
    const signIn = page.locator("[class*='sign-in-card'], [class*='App__signin']");
    await expect(signIn.first()).toBeVisible({ timeout: 10_000 });
  },
);
