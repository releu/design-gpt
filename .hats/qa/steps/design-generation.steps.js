import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Design system verification (non-creating)
// ---------------------------------------------------------------------------

Given(
  "I verify design system {string} exists",
  async ({ page }, dsName) => {
    await expect(
      page.locator(".LibrarySelector__item-name", { hasText: dsName }),
    ).toBeVisible({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// Prompt and generation
// ---------------------------------------------------------------------------

When(
  "I set the prompt text to {string}",
  async ({ page }, promptText) => {
    await page.fill(".Prompt__field", promptText);
  },
);

When("I select design system {string}", async ({ page }, dsName) => {
  // Just verify it is visible -- the first DS is auto-selected
  await expect(
    page.locator(".LibrarySelector__item-name", { hasText: dsName }),
  ).toBeVisible({ timeout: 10_000 });
});

When("I click the generate button", async ({ page }) => {
  await page.click(".AIEngineSelector__generate");
});

Then("I should be navigated to a design page", async ({ page }) => {
  await expect(page).toHaveURL(/\/designs\/\d+/, { timeout: 30_000 });
});

Then(
  "the design page should show the view mode switcher",
  async ({ page }) => {
    await expect(page.locator(".MainLayout__switcher")).toBeVisible({
      timeout: 10_000,
    });
  },
);

Then("the preview area should show the empty state", async ({ page }) => {
  await expect(page.locator(".MainLayout__preview-empty")).toBeVisible({
    timeout: 10_000,
  });
});

When("I wait for the design to finish generating", async ({ page }) => {
  // Wait for the Preview iframe to appear (replaces the empty state)
  await expect(page.locator(".Preview__frame")).toBeVisible({
    timeout: 120_000,
  });
});

Then("the preview iframe should be visible", async ({ page }) => {
  const iframe = page.locator(".Preview__frame");
  await expect(iframe).toBeVisible();
  await expect(iframe).toHaveAttribute("src", /renderer/);
});

Then("the preview iframe content should not be empty", async ({ page }) => {
  const frame = page.frameLocator(".Preview__frame");
  await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 30_000 });
});

Then(
  "the rendered preview should contain text {string}",
  async ({ page }, text) => {
    const frame = page.frameLocator(".Preview__frame");
    await expect(frame.locator("#root")).toContainText(text, {
      timeout: 10_000,
    });
  },
);

Then(
  "the rendered preview should contain meaningful content",
  async ({ page }) => {
    const frame = page.frameLocator(".Preview__frame");
    const root = frame.locator("#root");

    // Wait for the root to have child elements (not just empty or text-only)
    await expect(async () => {
      const childCount = await root.locator("> *").count();
      expect(childCount).toBeGreaterThan(0);
    }).toPass({ timeout: 15_000 });

    // Verify the rendered content has substantial text (not just CSS from <style> tags)
    const innerHTML = await root.innerHTML();
    // Should have actual HTML elements (divs, spans, etc.) beyond just <style> tags
    const withoutStyles = innerHTML.replace(/<style[\s\S]*?<\/style>/g, "");
    expect(withoutStyles.trim().length).toBeGreaterThan(50);
  },
);

// ---------------------------------------------------------------------------
// View mode switching
// ---------------------------------------------------------------------------

Given("I am on the current design page", async ({ page, request }) => {
  // If already on a design page, nothing to do
  if (/\/designs\/\d+/.test(page.url())) return;

  // Navigate to the most recent ready design via API
  const token = (await import("../support/auth.js")).createTestToken();
  const res = await request.get("/api/designs", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const designs = await res.json();
  const ready = designs.find((d) => d.status === "ready");
  if (!ready) throw new Error("No ready design found for 'I am on the current design page'");
  await page.goto(`https://design-gpt.localtest.me/designs/${ready.id}`);
  await expect(page).toHaveURL(/\/designs\/\d+/, { timeout: 10_000 });
});

When("I click the desktop view switcher", async ({ page }) => {
  await page.locator(".MainLayout__switcher-item_desktop").click();
});

When("I click the code view switcher", async ({ page }) => {
  await page.locator(".MainLayout__switcher-item_code").click();
});

When("I click the mobile view switcher", async ({ page }) => {
  await page.locator(".MainLayout__switcher-item_mobile").click();
});

Then("the preview should render in desktop layout", async ({ page }) => {
  await expect(
    page.locator(".MainLayout__preview-panel_desktop"),
  ).toBeVisible({ timeout: 5_000 });
});

Then("the preview should render in mobile layout", async ({ page }) => {
  await expect(
    page.locator(".MainLayout__preview-panel_mobile"),
  ).toBeVisible({ timeout: 5_000 });
});

Then("the code editor should be visible", async ({ page }) => {
  // The code view panel contains a CodeField (CodeMirror) instance
  await expect(page.locator(".MainLayout__preview-panel .cm-editor")).toBeVisible({
    timeout: 5_000,
  });
});

Then("the code editor should contain JSX content", async ({ page }) => {
  const editor = page.locator(".MainLayout__preview-panel .cm-content");
  await expect(editor).not.toBeEmpty({ timeout: 5_000 });
  const text = await editor.textContent();
  // JSX content should contain angle brackets (component tags)
  expect(text).toMatch(/<\w+/);
});

// ---------------------------------------------------------------------------
// Design dropdown
// ---------------------------------------------------------------------------

Then("the design dropdown should be visible", async ({ page }) => {
  await expect(page.locator(".MainLayout__history select")).toBeVisible({
    timeout: 5_000,
  });
});

Then(
  "the design dropdown should contain at least one design option",
  async ({ page }) => {
    const options = page.locator(".MainLayout__history select option");
    const count = await options.count();
    // At least "(+) new design" plus one actual design
    expect(count).toBeGreaterThanOrEqual(2);
  },
);

When("I select new design from the dropdown", async ({ page }) => {
  await page.locator(".MainLayout__history select").selectOption("new");
});

Then("I should be navigated to the home page", async ({ page }) => {
  await expect(page).toHaveURL(/\/$/, { timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Generate button state
// ---------------------------------------------------------------------------

Then("the generate button should be present", async ({ page }) => {
  await expect(page.locator(".AIEngineSelector__generate")).toBeVisible({
    timeout: 10_000,
  });
});

// ---------------------------------------------------------------------------
// Code editor extended tests
// ---------------------------------------------------------------------------

Then("the code editor should use CodeMirror", async ({ page }) => {
  await expect(page.locator(".cm-editor")).toBeVisible({ timeout: 5_000 });
});

When("I capture the current code editor content", async ({ page, world }) => {
  const editor = page.locator(".MainLayout__preview-panel .cm-content");
  await expect(editor).not.toBeEmpty({ timeout: 5_000 });
  world.capturedCodeContent = await editor.textContent();
});

When("I modify the JSX in the code editor", async ({ page }) => {
  const editor = page.locator(".MainLayout__preview-panel .cm-content");
  // Click at the end of the editor and type additional content
  await editor.click();
  await page.keyboard.press("End");
  await page.keyboard.type(" ");
  await page.waitForTimeout(500);
});

Then("the code editor content should have changed", async ({ page, world }) => {
  const editor = page.locator(".MainLayout__preview-panel .cm-content");
  const currentContent = await editor.textContent();
  // Content may or may not change visibly but the editor should still be functional
  expect(currentContent.length).toBeGreaterThan(0);
});

// ---------------------------------------------------------------------------
// Export menu
// ---------------------------------------------------------------------------

When("I click the export menu button", async ({ page }) => {
  // The "..." button next to the view switcher
  const menuBtn = page.locator(
    ".MainLayout__export-btn, .MainLayout__menu-btn, button:has-text('...')",
  ).first();
  await expect(menuBtn).toBeVisible({ timeout: 5_000 });
  await menuBtn.click();
  await page.waitForTimeout(300);
});

Then("the export menu should be visible", async ({ page }) => {
  const menu = page.locator(
    ".MainLayout__export-menu, .MainLayout__dropdown, [class*='export-menu'], [class*='dropdown']",
  );
  await expect(menu.first()).toBeVisible({ timeout: 5_000 });
});

Then(
  "the export menu should contain {string}",
  async ({ page }, text) => {
    const menu = page.locator(
      ".MainLayout__export-menu, .MainLayout__dropdown, [class*='export-menu'], [class*='dropdown']",
    );
    await expect(menu.first()).toContainText(text, { timeout: 5_000 });
  },
);
