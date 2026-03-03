import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

Given(
  "I had a previously added design system {string}",
  async ({ page }, dsName) => {
    await expect(
      page.locator(".LibrarySelector__item-name", { hasText: dsName }),
    ).toBeVisible({ timeout: 10_000 });
  },
);

When("I set the prompt to {string}", async ({ page }, promptText) => {
  await page.fill(".Prompt__field", promptText);
});

When("I select the design system {string}", async ({ page }, dsName) => {
  await expect(
    page.locator(".LibrarySelector__item-name", { hasText: dsName }),
  ).toBeVisible({ timeout: 10_000 });
});

Then("I should be navigated to a design page", async ({ page }) => {
  await expect(page).toHaveURL(/\/designs\/\d+/, { timeout: 30_000 });
});

Then(
  "I should see the design page layout with switcher and preview",
  async ({ page }) => {
    await expect(page.locator(".MainLayout__switcher")).toBeVisible({
      timeout: 10_000,
    });
    await expect(page.locator(".MainLayout__preview")).toBeVisible();
  },
);

Then("the preview should show the empty state", async ({ page }) => {
  await expect(page.locator(".MainLayout__preview-empty")).toBeVisible({
    timeout: 10_000,
  });
});

When("I wait for the design generation to complete", async ({ page }) => {
  await expect(page.locator(".Preview__frame")).toBeVisible({
    timeout: 120_000,
  });
});

Then("the preview should display the generated design", async ({ page }) => {
  const iframe = page.locator(".Preview__frame");
  await expect(iframe).toBeVisible();
  await expect(iframe).toHaveAttribute("src", /renderer/);

  // Verify actual content rendered inside the iframe (not just an empty shell)
  const frame = page.frameLocator(".Preview__frame");
  await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 30_000 });
});

Then(
  "the rendered preview should contain {string}",
  async ({ page }, text) => {
    const frame = page.frameLocator(".Preview__frame");
    await expect(frame.locator("#root")).toContainText(text, {
      timeout: 10_000,
    });
  },
);
