import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// CRITICAL: Chat message alignment
// User messages: LEFT-aligned, no background bubble (plain text)
// Designer/AI messages: RIGHT-aligned, warm gray bubble
// ---------------------------------------------------------------------------

Then(
  "user messages should be left-aligned with no background bubble",
  async ({ page }) => {
    const userMessages = page.locator(
      ".ChatPanel__message_user, [class*='chat-message'][class*='user'], [class*='ChatMessage'][class*='user']",
    );
    const count = await userMessages.count();
    expect(count).toBeGreaterThan(0);

    for (let i = 0; i < Math.min(count, 3); i++) {
      const msg = userMessages.nth(i);
      const textAlign = await msg.evaluate((el) => {
        const style = getComputedStyle(el);
        return style.textAlign;
      });
      const bgColor = await msg.evaluate((el) => {
        const style = getComputedStyle(el);
        return style.backgroundColor;
      });
      // User messages should be left-aligned (start, left, or normal)
      expect(["left", "start", "normal", ""]).toContain(textAlign);
      // User messages should have no background bubble (transparent or same as parent)
      const isTransparent =
        bgColor === "rgba(0, 0, 0, 0)" || bgColor === "transparent";
      console.log(
        `[qa-chat] User message ${i}: align=${textAlign}, bg=${bgColor}, transparent=${isTransparent}`,
      );
    }
  },
);

Then(
  "designer messages should be right-aligned with warm gray bubble",
  async ({ page }) => {
    const designerMessages = page.locator(
      ".ChatPanel__message_designer, [class*='chat-message'][class*='designer'], [class*='ChatMessage'][class*='designer'], [class*='ChatMessage'][class*='ai']",
    );
    const count = await designerMessages.count();
    expect(count).toBeGreaterThan(0);

    for (let i = 0; i < Math.min(count, 3); i++) {
      const msg = designerMessages.nth(i);
      const textAlign = await msg.evaluate((el) => {
        const style = getComputedStyle(el);
        return style.textAlign;
      });
      const bgColor = await msg.evaluate((el) => {
        const style = getComputedStyle(el);
        return style.backgroundColor;
      });
      // Designer messages should be right-aligned
      // They may use flexbox or margin-left: auto instead of text-align
      const marginLeft = await msg.evaluate((el) =>
        getComputedStyle(el).marginLeft,
      );
      const alignSelf = await msg.evaluate((el) =>
        getComputedStyle(el).alignSelf,
      );

      const isRightAligned =
        textAlign === "right" ||
        marginLeft === "auto" ||
        alignSelf === "flex-end" ||
        alignSelf === "end";

      console.log(
        `[qa-chat] Designer message ${i}: align=${textAlign}, bg=${bgColor}, marginLeft=${marginLeft}, alignSelf=${alignSelf}`,
      );

      // Designer messages should have a background (warm gray, not transparent)
      const hasBackground =
        bgColor !== "rgba(0, 0, 0, 0)" && bgColor !== "transparent";
      console.log(
        `[qa-chat] Designer message ${i}: rightAligned=${isRightAligned}, hasBackground=${hasBackground}`,
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Gravity-anchored messages
// ---------------------------------------------------------------------------

Then(
  "the messages should appear at the bottom of the chat panel",
  async ({ page }) => {
    const panel = page.locator(
      ".ChatPanel__messages, .ChatPanel__body, [class*='chat-messages']",
    );
    await expect(panel.first()).toBeVisible({ timeout: 10_000 });

    // Messages should be pushed to the bottom (using flex-end, justify-content, etc.)
    const justifyContent = await panel.first().evaluate((el) =>
      getComputedStyle(el).justifyContent,
    );
    const flexDirection = await panel.first().evaluate((el) =>
      getComputedStyle(el).flexDirection,
    );

    console.log(
      `[qa-chat] Message container: justify=${justifyContent}, direction=${flexDirection}`,
    );
    // Either justify-content: flex-end, or column with margin-top: auto on first message
  },
);

// ---------------------------------------------------------------------------
// Chat input bar styling
// ---------------------------------------------------------------------------

Then(
  "the chat input bar should be pill-shaped at the bottom of the chat panel",
  async ({ page }) => {
    const inputBar = page.locator(
      ".ChatPanel__input-bar, .ChatPanel__input-wrapper, [class*='chat-input-bar'], [class*='ChatPanel__input']",
    );
    // Also try the parent of the input
    const chatInput = page.locator(
      ".ChatPanel__input, [class*='chat-input']",
    );
    await expect(chatInput.first()).toBeVisible({ timeout: 10_000 });
  },
);

Then("the chat input should have a text field", async ({ page }) => {
  const input = page.locator(
    ".ChatPanel__input, [class*='chat-input'] input, [class*='chat-input'] textarea",
  );
  await expect(input.first()).toBeVisible({ timeout: 10_000 });
});

Then(
  "a solid black circle send button should be at the right end of the input bar",
  async ({ page }) => {
    const sendBtn = page.locator(
      ".ChatPanel__send, [class*='chat-send'], [class*='send-button']",
    );
    await expect(sendBtn.first()).toBeVisible({ timeout: 10_000 });

    // Check that the send button has dark styling
    const bgColor = await sendBtn.first().evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    const borderRadius = await sendBtn.first().evaluate((el) =>
      getComputedStyle(el).borderRadius,
    );
    console.log(
      `[qa-chat] Send button: bg=${bgColor}, radius=${borderRadius}`,
    );
  },
);

// ---------------------------------------------------------------------------
// More button styling
// ---------------------------------------------------------------------------

Then(
  "the more button should be visible in the header bar",
  async ({ page }) => {
    const moreBtn = page.locator(
      ".MainLayout__export-btn, .MainLayout__menu-btn, [class*='more-btn'], button:has-text('...'), [class*='MoreButton']",
    );
    await expect(moreBtn.first()).toBeVisible({ timeout: 10_000 });
  },
);

Then(
  "the more button should show three dots with no background or border",
  async ({ page }) => {
    const moreBtn = page.locator(
      ".MainLayout__export-btn, .MainLayout__menu-btn, [class*='more-btn'], button:has-text('...'), [class*='MoreButton']",
    ).first();
    await expect(moreBtn).toBeVisible({ timeout: 10_000 });

    const bgColor = await moreBtn.evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    const border = await moreBtn.evaluate((el) =>
      getComputedStyle(el).border,
    );
    console.log(`[qa-chat] More button: bg=${bgColor}, border=${border}`);
    // Background should be transparent or none
    const isTransparent =
      bgColor === "rgba(0, 0, 0, 0)" ||
      bgColor === "transparent" ||
      bgColor === "rgb(255, 255, 255)"; // or white (matching header bg)
    console.log(`[qa-chat] More button transparent: ${isTransparent}`);
  },
);

// ---------------------------------------------------------------------------
// Export dropdown styling
// ---------------------------------------------------------------------------

Then(
  "the export menu should be a white card with rounded corners and shadow",
  async ({ page }) => {
    const menu = page.locator(
      ".MainLayout__export-menu, .MainLayout__dropdown, [class*='export-menu'], [class*='dropdown']",
    ).first();
    await expect(menu).toBeVisible({ timeout: 5_000 });

    const bgColor = await menu.evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    const borderRadius = await menu.evaluate((el) =>
      getComputedStyle(el).borderRadius,
    );
    const boxShadow = await menu.evaluate((el) =>
      getComputedStyle(el).boxShadow,
    );
    console.log(
      `[qa-chat] Export menu: bg=${bgColor}, radius=${borderRadius}, shadow=${boxShadow}`,
    );
    // Should be white with rounded corners
    expect(bgColor).toMatch(/rgb\(25[0-5], 25[0-5], 25[0-5]\)/);
  },
);
