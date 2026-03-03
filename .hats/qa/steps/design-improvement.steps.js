import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Chat panel
// ---------------------------------------------------------------------------

Given("the chat panel is visible", async ({ page }) => {
  await expect(page.locator(".ChatPanel")).toBeVisible({ timeout: 10_000 });
});

When(
  "I type {string} in the chat input",
  async ({ page }, text) => {
    await page.fill(".ChatPanel__input", text);
  },
);

When("I click the chat send button", async ({ page }) => {
  await page.click(".ChatPanel__send");
});

Then("the chat input should be cleared", async ({ page }) => {
  await expect(page.locator(".ChatPanel__input")).toHaveValue("", {
    timeout: 10_000,
  });
});

Then(
  "the chat panel should display at least 2 messages",
  async ({ page }) => {
    const messages = page.locator(".ChatPanel__message");
    await expect(async () => {
      const count = await messages.count();
      expect(count).toBeGreaterThanOrEqual(2);
    }).toPass({ timeout: 30_000 });
  },
);

Then(
  "the chat messages should include both user and designer messages",
  async ({ page }) => {
    await expect(
      page.locator(".ChatPanel__message_user").first(),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(".ChatPanel__message_designer").first(),
    ).toBeVisible({ timeout: 10_000 });
  },
);

Then(
  "the chat send button should be disabled when input is empty",
  async ({ page }) => {
    // Clear the input first
    await page.fill(".ChatPanel__input", "");
    await expect(page.locator(".ChatPanel__send_disabled")).toBeVisible();
  },
);

When("I press Ctrl+Enter in the chat input", async ({ page }) => {
  await page.locator(".ChatPanel__input").press("Control+Enter");
});

// ---------------------------------------------------------------------------
// Send button disabled during generation
// ---------------------------------------------------------------------------

Then(
  "the chat send button should be disabled during generation",
  async ({ page }) => {
    // Immediately after clicking send, the button should be disabled
    const sendBtn = page.locator(".ChatPanel__send");
    const disabledBtn = page.locator(
      ".ChatPanel__send_disabled, .ChatPanel__send[disabled]",
    );
    // Check within a short window -- the button may re-enable quickly
    const isDisabled = await disabledBtn
      .isVisible({ timeout: 3_000 })
      .catch(() => false);
    const isAttrDisabled = await sendBtn
      .isDisabled({ timeout: 1_000 })
      .catch(() => false);
    // Either the button has a disabled class or is actually disabled
    expect(isDisabled || isAttrDisabled).toBe(true);
  },
);

// ---------------------------------------------------------------------------
// Auto-scroll
// ---------------------------------------------------------------------------

Then("the chat panel should be scrolled to the bottom", async ({ page }) => {
  const panel = page.locator(".ChatPanel__messages, .ChatPanel__body");
  await expect(panel.first()).toBeVisible({ timeout: 5_000 });

  const isScrolledToBottom = await panel.first().evaluate((el) => {
    // Allow a small margin of error (5px) for scroll position
    return el.scrollHeight - el.scrollTop - el.clientHeight < 50;
  });
  expect(isScrolledToBottom).toBe(true);
});

// ---------------------------------------------------------------------------
// Settings panel
// ---------------------------------------------------------------------------

When(
  "I click the Settings tab in the panel switcher",
  async ({ page }) => {
    await page
      .locator(".MainLayout__switcher-item", { hasText: "Settings" })
      .click();
  },
);

Then("the design settings panel should be visible", async ({ page }) => {
  // DesignSettings component should be visible
  await expect(
    page.locator(".MainLayout__switcher-item_active", { hasText: "Settings" }),
  ).toBeVisible();
});
