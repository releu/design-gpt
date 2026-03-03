import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Finding components with specific prop types
// ---------------------------------------------------------------------------

When(
  "I click a component that has variant props",
  async ({ page, world }) => {
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();

    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      // Check if this component has variant props (select elements)
      const propSelect = page.locator(".ComponentDetail__prop-row select");
      if (await propSelect.first().isVisible({ timeout: 2_000 }).catch(() => false)) {
        world.selectedComponentName = text;
        console.log(`[qa-browser] Found component with variant props: ${text}`);
        return;
      }
    }

    throw new Error("No component with variant props found in the library");
  },
);

When(
  "I click a component that has React code",
  async ({ page, world }) => {
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();

    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      // Check if this component has the "ready" status badge
      const statusBadge = await page
        .locator(".ComponentDetail__status-badge")
        .textContent({ timeout: 2_000 })
        .catch(() => "");
      if (statusBadge.trim() === "ready") {
        world.selectedComponentName = text;
        console.log(`[qa-browser] Found component with React code: ${text}`);
        return;
      }
    }

    throw new Error("No component with React code found in the library");
  },
);

// ---------------------------------------------------------------------------
// Props section
// ---------------------------------------------------------------------------

Then("the Props section should list available props", async ({ page }) => {
  const propRows = page.locator(".ComponentDetail__prop-row");
  const count = await propRows.count();
  expect(count).toBeGreaterThan(0);
  console.log(`[qa-browser] Props section shows ${count} props`);
});

Then("variant props should have dropdown selects", async ({ page }) => {
  const selects = page.locator(".ComponentDetail__prop-row select");
  await expect(selects.first()).toBeVisible();

  // Verify the select has options
  const options = await selects.first().locator("option").allTextContents();
  expect(options.length).toBeGreaterThan(0);
  console.log(
    `[qa-browser] First variant prop has ${options.length} options: ${options.slice(0, 5).join(", ")}`,
  );
});

// ---------------------------------------------------------------------------
// Preview content capture and comparison
// ---------------------------------------------------------------------------

When("I capture the current preview content", async ({ page, world }) => {
  const frame = page.frameLocator(".ComponentDetail__preview-frame");
  await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 10_000 });
  world.capturedPreviewHtml = await frame.locator("#root").innerHTML();
});

When(
  "I change the first variant prop to a different value",
  async ({ page }) => {
    const select = page.locator(".ComponentDetail__prop-row select").first();
    const options = await select.locator("option").allTextContents();
    const currentValue = await select.inputValue();

    // Pick a different value
    const differentValue = options.find(
      (o) => o.trim() !== currentValue.trim(),
    );
    if (differentValue) {
      await select.selectOption(differentValue.trim());
      await page.waitForTimeout(800);
    }
  },
);

Then(
  "the preview iframe content should differ from the captured content",
  async ({ page, world }) => {
    const frame = page.frameLocator(".ComponentDetail__preview-frame");
    await expect(async () => {
      const currentHtml = await frame.locator("#root").innerHTML();
      expect(currentHtml).not.toBe(world.capturedPreviewHtml);
    }).toPass({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// React Code section
// ---------------------------------------------------------------------------

When("I expand the React Code section", async ({ page }) => {
  const codeHeader = page.locator(".ComponentDetail__section-header", {
    hasText: "React Code",
  });
  if (await codeHeader.isVisible().catch(() => false)) {
    await codeHeader.click();
  }
});

Then(
  "the code section should display React source code",
  async ({ page }) => {
    const codeWrap = page.locator(".ComponentDetail__code-wrap");
    await expect(codeWrap).toBeVisible({ timeout: 5_000 });

    // CodeMirror editor should have content
    const editor = codeWrap.locator(".cm-content");
    await expect(editor).not.toBeEmpty({ timeout: 5_000 });
    const text = await editor.textContent();
    // React code should contain function or export keywords
    expect(text).toMatch(/function|export|return|React/i);
    console.log(
      `[qa-browser] React code section shows ${text.length} chars of code`,
    );
  },
);

// ---------------------------------------------------------------------------
// Libraries list page
// ---------------------------------------------------------------------------

Given("I navigate to the libraries page", async ({ page }) => {
  await page.goto("/libraries");
  await page.waitForLoadState("domcontentloaded");
});

Then(
  "the libraries page should display at least one library card",
  async ({ page }) => {
    const cards = page.locator(
      "[class*='library-card'], [class*='LibraryCard'], .libraries-list [class*='card']",
    );
    await expect(async () => {
      const count = await cards.count();
      expect(count).toBeGreaterThanOrEqual(1);
    }).toPass({ timeout: 15_000 });
  },
);

Then(
  "each library card should show a name and status",
  async ({ page }) => {
    const firstCard = page.locator(
      "[class*='library-card'], [class*='LibraryCard'], .libraries-list [class*='card']",
    ).first();
    const text = await firstCard.textContent();
    expect(text.trim().length).toBeGreaterThan(0);
  },
);

When("I click the first library card", async ({ page }) => {
  const card = page.locator(
    "[class*='library-card'], [class*='LibraryCard'], .libraries-list [class*='card']",
  ).first();
  await card.click();
  await page.waitForTimeout(500);
});

Then(
  "I should be navigated to a library detail page",
  async ({ page }) => {
    await expect(page).toHaveURL(/\/libraries\/\d+/, { timeout: 10_000 });
  },
);

Then(
  "the library detail page should display the library name",
  async ({ page }) => {
    // The page should have some heading or name element
    const heading = page.locator("h1, h2, [class*='library-name'], [class*='LibraryDetail__name']");
    await expect(heading.first()).toBeVisible({ timeout: 10_000 });
    const text = await heading.first().textContent();
    expect(text.trim().length).toBeGreaterThan(0);
  },
);

// ---------------------------------------------------------------------------
// Component preview page
// ---------------------------------------------------------------------------

When(
  "I load the component preview page for {string}",
  async ({ page, request, world }, dsName) => {
    // Find the library ID via API
    const token = createTestToken();
    const res = await request.get("/api/component-libraries", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const libs = await res.json();
    const readyLib = libs.find((l) => l.status === "ready");

    if (!readyLib) {
      throw new Error("No ready library found for preview page test");
    }

    world.previewPageUrl = `/api/component-libraries/${readyLib.id}/preview`;
    await page.goto(world.previewPageUrl);
    await page.waitForLoadState("domcontentloaded");
  },
);

Then(
  "the preview page should display components in a grid layout",
  async ({ page }) => {
    // The preview page should have component cards
    const cards = page.locator(
      "[class*='component-card'], [class*='ComponentCard'], [class*='preview-card']",
    );
    await expect(async () => {
      const count = await cards.count();
      expect(count).toBeGreaterThan(0);
    }).toPass({ timeout: 15_000 });
  },
);

Then(
  "each component card should show a name and type badge",
  async ({ page }) => {
    const firstCard = page.locator(
      "[class*='component-card'], [class*='ComponentCard'], [class*='preview-card']",
    ).first();
    const text = await firstCard.textContent();
    expect(text.trim().length).toBeGreaterThan(0);
  },
);
