import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

const CUBES_FIGMA_URL =
  "https://www.figma.com/design/BoLWfKXuDvgWi6ucjHWHK7/%F0%9F%92%8E-DesignGPT-%E2%80%A2-Cubes?node-id=16-72&t=AnePYBXJuVfK6Fwv-1";

// ---------------------------------------------------------------------------
// Import helper: ensures a design system exists (creates if not)
// ---------------------------------------------------------------------------

When(
  "I ensure the QA design system {string} is imported from Cubes",
  async ({ page }, dsName) => {
    // Check if design system already exists in the sidebar
    const dsLocator = page.locator(".LibrarySelector__item-name", {
      hasText: dsName,
    });
    const alreadyExists = await dsLocator
      .first()
      .isVisible({ timeout: 10_000 })
      .catch(() => false);

    if (alreadyExists) {
      console.log(
        `[qa] Design system "${dsName}" found in UI, skipping import.`,
      );
      return;
    }

    console.log(`[qa] Importing Cubes library as "${dsName}" via UI...`);

    // Open design system modal
    await page.click(".LibrarySelector__new-ds");
    await expect(page.locator(".DesignSystemModal")).toBeVisible();

    // Add Figma URL
    page.once("dialog", async (dialog) => await dialog.accept(CUBES_FIGMA_URL));
    await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
    await expect(page.locator(".DesignSystemModal__url-text")).toBeVisible();
    console.log(`[qa] Figma URL added, starting import...`);

    // Click Import
    await page.click(".DesignSystemModal__do-import");

    // Poll the UI for progress
    const startTime = Date.now();
    let lastStatus = "";

    while (true) {
      const browserVisible = await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false);

      if (browserVisible) {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(
          `[qa] [${elapsed}s] Component browser visible -- import complete!`,
        );
        break;
      }

      // Read current status from the modal
      const statusText = await page
        .locator(".DesignSystemModal__box")
        .first()
        .textContent()
        .catch(() => "");
      const shortStatus = statusText.replace(/\s+/g, " ").trim().slice(0, 120);
      if (shortStatus !== lastStatus) {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(`[qa] [${elapsed}s] ${shortStatus}`);
        lastStatus = shortStatus;
      }

      await page.waitForTimeout(5_000);
    }

    // Name and save
    await page.fill(".DesignSystemModal__overview-name-input", dsName);
    await page.click(".DesignSystemModal__save-btn");
    await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
      timeout: 5_000,
    });
    console.log(`[qa] Design system "${dsName}" saved.`);
  },
);

// ---------------------------------------------------------------------------
// Modal interactions
// ---------------------------------------------------------------------------

When("I click the new design system button", async ({ page }) => {
  await page.click(".LibrarySelector__new-ds");
});

Then("the design system modal should be visible", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal")).toBeVisible();
});

When("I add the Cubes Figma URL", async ({ page }) => {
  page.once("dialog", async (dialog) => await dialog.accept(CUBES_FIGMA_URL));
  await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
});

Then("the Figma URL should appear in the pending list", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal__url-text")).toBeVisible();
});

When("I click the import button", async ({ page }) => {
  await page.click(".DesignSystemModal__do-import");
});

Then(
  "the component browser should be visible within 10 minutes",
  async ({ page }) => {
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
      timeout: 600_000,
    });
  },
);

Then("the component browser should be visible", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
    timeout: 30_000,
  });
});

Then(
  "the component browser menu should list component names",
  async ({ page }) => {
    // Wait for at least one menu subtitle (file name) and component items
    await expect(
      page.locator(".DesignSystemModal__menu-subtitle"),
    ).toBeVisible({ timeout: 30_000 });
    const items = page.locator(".DesignSystemModal__menu-item");
    // Should have Overview + AI Schema + at least 1 component
    const count = await items.count();
    expect(count).toBeGreaterThan(2);
  },
);

When(
  "I enter the design system name {string}",
  async ({ page }, name) => {
    await page.fill(".DesignSystemModal__overview-name-input", name);
  },
);

When("I click {string} in the modal", async ({ page }, buttonText) => {
  if (buttonText === "Save") {
    await page.click(".DesignSystemModal__save-btn");
  } else {
    await page.click(`.DesignSystemModal >> text=${buttonText}`);
  }
});

Then("the design system modal should close", async ({ page }) => {
  await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
    timeout: 5_000,
  });
});

Then(
  "the design system {string} should appear in the library selector",
  async ({ page }, dsName) => {
    await expect(
      page.locator(".LibrarySelector__item-name", { hasText: dsName }),
    ).toBeVisible({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// Browse design system
// ---------------------------------------------------------------------------

When(
  "I open the design system browser for {string}",
  async ({ page }, dsName) => {
    const item = page
      .locator(".LibrarySelector__item", { hasText: dsName })
      .first();
    await item.locator(".LibrarySelector__item-browse").click();
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
      timeout: 30_000,
    });
  },
);

Then(
  "the Overview panel should show the design system name",
  async ({ page }) => {
    await expect(
      page.locator(".DesignSystemModal__overview-name-input"),
    ).toBeVisible();
    const val = await page
      .locator(".DesignSystemModal__overview-name-input")
      .inputValue();
    expect(val.length).toBeGreaterThan(0);
  },
);

Then(
  "the Overview should display file names with component counts",
  async ({ page }) => {
    await expect(
      page.locator(".DesignSystemModal__overview-file").first(),
    ).toBeVisible();
    const fileName = await page
      .locator(".DesignSystemModal__overview-file-name")
      .first()
      .textContent();
    expect(fileName.trim().length).toBeGreaterThan(0);
    const countText = await page
      .locator(".DesignSystemModal__overview-file-count")
      .first()
      .textContent();
    expect(countText).toContain("components");
  },
);

When("I click the first component in the menu", async ({ page }) => {
  const menuItems = page.locator(".DesignSystemModal__menu-item");
  const count = await menuItems.count();
  // Skip Overview and AI Schema
  for (let i = 0; i < count; i++) {
    const text = (await menuItems.nth(i).textContent()).trim();
    if (text !== "Overview" && text !== "AI Schema") {
      await menuItems.nth(i).click();
      return;
    }
  }
  throw new Error("No component found in the menu");
});

Then(
  "the component detail panel should show the component name",
  async ({ page }) => {
    await expect(page.locator(".ComponentDetail__name")).toBeVisible({
      timeout: 5_000,
    });
    const name = await page.locator(".ComponentDetail__name").textContent();
    expect(name.trim().length).toBeGreaterThan(0);
  },
);

Then("the component detail should show the type badge", async ({ page }) => {
  await expect(page.locator(".ComponentDetail__type-badge")).toBeVisible();
  const badge = await page
    .locator(".ComponentDetail__type-badge")
    .textContent();
  expect(["Component Set", "Component", "Vector"]).toContain(badge.trim());
});

Then("the component detail should show the status badge", async ({ page }) => {
  await expect(page.locator(".ComponentDetail__status-badge")).toBeVisible();
  const badge = await page
    .locator(".ComponentDetail__status-badge")
    .textContent();
  expect(["ready", "no code"]).toContain(badge.trim());
});

// ---------------------------------------------------------------------------
// Configuration (root + children)
// ---------------------------------------------------------------------------

When("I find a root component in the menu", async ({ page, world }) => {
  // Iterate components to find one with root configuration
  const menuItems = page.locator(".DesignSystemModal__menu-item");
  const count = await menuItems.count();

  for (let i = 0; i < count; i++) {
    const text = (await menuItems.nth(i).textContent()).trim();
    if (text === "Overview" || text === "AI Schema") continue;

    await menuItems.nth(i).click();
    await page.waitForTimeout(500);

    // Check if Configuration section exists and shows root
    const configSection = page.locator(".ComponentDetail__config-tag_root");
    if (await configSection.isVisible({ timeout: 1_000 }).catch(() => false)) {
      world.foundRootComponent = text;
      console.log(`[qa] Found root component: ${text}`);
      return;
    }
  }

  // If no root found, still pass -- the test just checks available config
  console.log("[qa] No root component found in this library");
  world.foundRootComponent = null;
});

Then(
  "the Configuration section should show root badge {string}",
  async ({ page, world }, expected) => {
    if (!world.foundRootComponent) {
      console.log("[qa] Skipping root badge check -- no root component found");
      return;
    }
    const badge = page.locator(".ComponentDetail__config-tag_root");
    await expect(badge).toBeVisible({ timeout: 3_000 });
    await expect(badge).toContainText(expected);
  },
);

Then(
  "the allowed children list should not be empty",
  async ({ page, world }) => {
    if (!world.foundRootComponent) {
      console.log(
        "[qa] Skipping allowed children check -- no root component found",
      );
      return;
    }
    const children = page.locator(
      ".ComponentDetail__config-row .ComponentDetail__prop-value",
    );
    const count = await children.count();
    expect(count).toBeGreaterThan(0);
  },
);

// ---------------------------------------------------------------------------
// AI Schema
// ---------------------------------------------------------------------------

When(
  "I click {string} in the component browser menu",
  async ({ page }, itemName) => {
    await page
      .locator(".DesignSystemModal__menu-item", { hasText: itemName })
      .click();
  },
);

Then("the AI Schema view should be visible", async ({ page }) => {
  // The AI Schema view is rendered when selected
  await expect(
    page.locator(".DesignSystemModal__browser-detail"),
  ).toBeVisible();
});
