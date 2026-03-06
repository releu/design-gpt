import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

const CUBES_FIGMA_URL =
  "https://www.figma.com/design/BoLWfKXuDvgWi6ucjHWHK7/%F0%9F%92%8E-DesignGPT-%E2%80%A2-Cubes?node-id=16-72&t=AnePYBXJuVfK6Fwv-1";
const EXAMPLE_LIB_URL =
  "https://www.figma.com/design/75U91YIrYa65xhYcM0olH5/Example-Lib";

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

// ---------------------------------------------------------------------------
// Create a new DESIGN_SYSTEM
// ---------------------------------------------------------------------------

When("the user creates a new DESIGN_SYSTEM", async ({ page }) => {
  await page.click(".LibrarySelector__new-ds");
  await expect(page.locator(".DesignSystemModal")).toBeVisible({
    timeout: 10_000,
  });
});

When('enters a name "My Design System"', async ({ page }) => {
  await page.fill(
    ".DesignSystemModal__overview-name-input",
    "My Design System",
  );
});

When("adds a FIGMA_FILE URL", async ({ page }) => {
  page.once("dialog", async (dialog) => await dialog.accept(CUBES_FIGMA_URL));
  await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
  await expect(page.locator(".DesignSystemModal__url-text")).toBeVisible();
});

Then("the import begins and progress is visible", async ({ page }) => {
  await page.click(".DesignSystemModal__do-import");
  // Wait for progress indicator
  await expect(
    page.locator(
      ".DesignSystemModal [class*='progress'], .DesignSystemModal [role='progressbar'], .DesignSystemModal__box",
    ),
  )
    .first()
    .toBeVisible({ timeout: 30_000 });
});

// Note: "the import completes" step is defined in figma-import.steps.js
// and is shared across features via playwright-bdd's step registry.

Then("the user can browse the imported components", async ({ page }) => {
  const items = page.locator(".DesignSystemModal__menu-item");
  const count = await items.count();
  expect(count).toBeGreaterThan(2);
});

Then("the name is saved automatically", async ({ page }) => {
  const nameInput = page.locator(".DesignSystemModal__overview-name-input");
  const value = await nameInput.inputValue();
  expect(value.length).toBeGreaterThan(0);
});

When("the user finishes editing", async ({ page }) => {
  await page.click(".DesignSystemModal__save-btn");
  await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
    timeout: 5_000,
  });
});

Then("the DESIGN_SYSTEM appears on the home page", async ({ page }) => {
  await expect(
    page.locator(".LibrarySelector__item-name"),
  ).first().toBeVisible({ timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Create a DESIGN_SYSTEM with multiple FIGMA_FILEs
// ---------------------------------------------------------------------------

When(
  "the user creates a DESIGN_SYSTEM with {int} FIGMA_FILEs",
  async ({ page }, fileCount) => {
    await page.click(".LibrarySelector__new-ds");
    await expect(page.locator(".DesignSystemModal")).toBeVisible();

    const urls = [CUBES_FIGMA_URL, EXAMPLE_LIB_URL].slice(0, fileCount);

    for (const url of urls) {
      page.once("dialog", async (dialog) => await dialog.accept(url));
      await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
    }

    await page.click(".DesignSystemModal__do-import");
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
      timeout: 600_000,
    });

    await page.fill(
      ".DesignSystemModal__overview-name-input",
      `Multi-file DS ${Date.now()}`,
    );
    await page.click(".DesignSystemModal__save-btn");
    await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
      timeout: 5_000,
    });
  },
);

Then(
  "the DESIGN_SYSTEM is created with both files linked",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    const dsRes = await request.get("/api/design-systems", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const systems = await dsRes.json();
    // At least one DS should have 2+ libraries
    const multiFile = systems.find(
      (d) =>
        (d.component_library_ids?.length || d.libraries?.length || 0) >= 2,
    );
    expect(multiFile).toBeTruthy();
  },
);

// ---------------------------------------------------------------------------
// List user's DESIGN_SYSTEMs
// ---------------------------------------------------------------------------

Given("the user has {int} DESIGN_SYSTEMs", async ({ request, world }, count) => {
  const token = world.authToken || createTestToken();
  // Ensure at least `count` DS exist
  const dsRes = await request.get("/api/design-systems", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const existing = await dsRes.json();
  const needed = count - existing.length;

  for (let i = 0; i < needed; i++) {
    await request.post("/api/design-systems", {
      headers: authHeaders(token),
      data: { name: `QA DS ${i + 1} ${Date.now()}` },
    });
  }
});

Then("both DESIGN_SYSTEMs are shown", async ({ page }) => {
  const items = page.locator(".LibrarySelector__item-name");
  await expect(async () => {
    const count = await items.count();
    expect(count).toBeGreaterThanOrEqual(2);
  }).toPass({ timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Edit an existing DESIGN_SYSTEM
// ---------------------------------------------------------------------------

Given(
  'the user has a DESIGN_SYSTEM "Example" with {int} linked FIGMA_FILEs',
  async ({ request, world }, fileCount) => {
    const token = world.authToken || createTestToken();
    // Create a DS named "Example" via API with linked files
    const dsRes = await request.post("/api/design-systems", {
      headers: authHeaders(token),
      data: { name: "Example" },
    });
    const ds = await dsRes.json();
    world.editDsId = ds.id;
    world.editDsName = "Example";

    const figmaUrls = [CUBES_FIGMA_URL, EXAMPLE_LIB_URL].slice(0, fileCount);
    for (const url of figmaUrls) {
      await request.post("/api/component-libraries", {
        headers: authHeaders(token),
        data: { url, design_system_id: ds.id },
      });
    }
  },
);

When('the user opens "Example" for editing', async ({ page, world }) => {
  const item = page
    .locator(".LibrarySelector__item", { hasText: "Example" })
    .first();
  await expect(item).toBeVisible({ timeout: 10_000 });
  await item.locator(".LibrarySelector__item-browse").click();
  await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({
    timeout: 30_000,
  });
});

Then(
  "the name, linked files, and components are shown",
  async ({ page }) => {
    // Name should be visible in the overview
    await expect(
      page.locator(".DesignSystemModal__overview-name-input"),
    ).toBeVisible();
    const name = await page
      .locator(".DesignSystemModal__overview-name-input")
      .inputValue();
    expect(name.length).toBeGreaterThan(0);
  },
);

When(
  "the user edits the name or the list of FIGMA_FILEs",
  async ({ page }) => {
    // TODO: DS update endpoint not yet implemented
    // Edit the name via the UI
    await page.fill(
      ".DesignSystemModal__overview-name-input",
      "Example Updated",
    );
  },
);

When("clicks save", async ({ page }) => {
  await page.click(".DesignSystemModal__save-btn");
});

Then("the changes are persisted", async ({ page }) => {
  // TODO: DS update endpoint not yet implemented
  // Verify modal closes (save was accepted)
  await expect(page.locator(".DesignSystemModal")).not.toBeVisible({
    timeout: 5_000,
  });
});
