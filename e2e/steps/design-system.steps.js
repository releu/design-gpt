import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

Then("the design system modal should be visible", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal")).toBeVisible();
});

When("I add a Figma URL {string}", async ({ page }, url) => {
  page.once("dialog", async (dialog) => {
    await dialog.accept(url);
  });
  await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
});

Then("the Figma URL should appear in the pending list", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal__url-text")).toBeVisible();
});

Then(
  "the component browser should be visible within 5 minutes",
  async ({ page }) => {
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
      timeout: 300_000,
    });
  },
);

When("I enter the design system name {string}", async ({ page }, name) => {
  await page.fill(".DesignSystemModal__overview-name-input", name);
});

When(
  "I click {string} in the component browser menu",
  async ({ page }, componentName) => {
    await page
      .locator(".DesignSystemModal__menu-item", { hasText: componentName })
      .click();
  },
);

When("I check the {string} checkbox", async ({ page }, label) => {
  if (label === "Root component") {
    const checkbox = page.locator(
      '.DesignSystemModal__root-toggle input[type="checkbox"]',
    );
    await checkbox.check();
    await expect(checkbox).toBeChecked();
  }
});

When("I add {string} as an allowed child", async ({ page }, childName) => {
  await page
    .locator(".DesignSystemModal__children-select")
    .selectOption({ label: childName });
  await page.click(".DesignSystemModal__children-add");
});

Then(
  "{string} should appear in the allowed children list",
  async ({ page }, childName) => {
    await expect(
      page.locator(".DesignSystemModal__children-item", {
        hasText: childName,
      }),
    ).toBeVisible();
  },
);

Then("the design system modal should close", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
    timeout: 5_000,
  });
});

Then(
  "a design system should appear in the library selector",
  async ({ page }) => {
    await expect(page.locator(".LibrarySelector__item-name").first()).toBeVisible({
      timeout: 10_000,
    });
  },
);

When("I open the design system {string}", async ({ page }, dsName) => {
  const item = page.locator(".LibrarySelector__item", { hasText: dsName }).first();
  await item.locator(".LibrarySelector__item-browse").click();
  await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
    timeout: 30_000,
  });
});

Then(
  "the component preview iframe should be visible",
  async ({ page }) => {
    await expect(
      page.locator(".ComponentDetail__preview-frame"),
    ).toBeVisible({ timeout: 10_000 });
  },
);

Then("the component preview should not be empty", async ({ page }) => {
  const frame = page.frameLocator(".ComponentDetail__preview-frame");
  await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 30_000 });
});

When(
  "I change the {string} prop to {string}",
  async ({ page, world }, propName, propValue) => {
    // Capture current preview content before changing
    const frame = page.frameLocator(".ComponentDetail__preview-frame");
    world.previousPreviewContent = await frame
      .locator("#root")
      .innerHTML();

    // Find the prop row and change the value (select for VARIANT, input for TEXT)
    const propRow = page.locator(".ComponentDetail__prop-row", {
      hasText: propName,
    });
    const select = propRow.locator("select");
    if (await select.isVisible().catch(() => false)) {
      await select.selectOption(propValue);
    } else {
      await propRow.locator('input[type="text"]').fill(propValue);
    }
  },
);

Then("the component preview should update", async ({ page, world }) => {
  const frame = page.frameLocator(".ComponentDetail__preview-frame");
  await expect(async () => {
    const content = await frame.locator("#root").innerHTML();
    expect(content).not.toBe(world.previousPreviewContent);
  }).toPass({ timeout: 10_000 });
});
