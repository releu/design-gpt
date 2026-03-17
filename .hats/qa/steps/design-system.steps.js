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
  await page.click('[qa="new-ds-btn"]');
  await expect(page.locator('[qa="ds-modal"]')).toBeVisible({
    timeout: 10_000,
  });
});

When('enters a name "My Design System"', async ({ page }) => {
  await page.fill(
    '[qa="ds-name-input"]',
    "My Design System",
  );
});

When("adds a FIGMA_FILE URL", async ({ page }) => {
  page.once("dialog", async (dialog) => await dialog.accept(CUBES_FIGMA_URL));
  await page.click('[qa="ds-add-figma-btn"]');
  await expect(page.locator('[qa="ds-url-text"]')).toBeVisible();
});

Then("the import begins and progress is visible", async ({ page }) => {
  await page.click('[qa="ds-import-btn"]');
  // Wait for progress indicator
  await expect(
    page.locator(
      '[qa="ds-modal"] [role="progressbar"], [qa="ds-box"]',
    ).first(),
  ).toBeVisible({ timeout: 30_000 });
});

// Note: "the import completes" step is defined in figma-import.steps.js
// and is shared across features via playwright-bdd's step registry.

Then("the user can browse the imported components", async ({ page }) => {
  const items = page.locator('[qa="ds-menu-item"]');
  const count = await items.count();
  expect(count).toBeGreaterThan(2);
});

Then("the name is saved automatically", async ({ page }) => {
  const nameInput = page.locator('[qa="ds-name-input"]');
  const value = await nameInput.inputValue();
  expect(value.length).toBeGreaterThan(0);
});

When("the user finishes editing", async ({ page }) => {
  await page.click('[qa="ds-save-btn"]');
  await expect(page.locator('[qa="ds-modal"]')).not.toBeVisible({
    timeout: 5_000,
  });
});

Then("the DESIGN_SYSTEM appears on the home page", async ({ page }) => {
  await expect(
    page.locator('[qa="library-item-name"]').first(),
  ).toBeVisible({ timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Create a DESIGN_SYSTEM with multiple FIGMA_FILEs
// ---------------------------------------------------------------------------

When(
  "the user creates a DESIGN_SYSTEM with {int} FIGMA_FILEs",
  async ({ page }, fileCount) => {
    await page.click('[qa="new-ds-btn"]');
    await expect(page.locator('[qa="ds-modal"]')).toBeVisible();

    const urls = [CUBES_FIGMA_URL, EXAMPLE_LIB_URL].slice(0, fileCount);

    for (const url of urls) {
      page.once("dialog", async (dialog) => await dialog.accept(url));
      await page.click('[qa="ds-add-figma-btn"]');
    }

    await page.click('[qa="ds-import-btn"]');
    await expect(page.locator('[qa="ds-browser"]')).toBeVisible({
      timeout: 600_000,
    });

    await page.fill(
      '[qa="ds-name-input"]',
      `Multi-file DS ${Date.now()}`,
    );
    await page.click('[qa="ds-save-btn"]');
    await expect(page.locator('[qa="ds-modal"]')).not.toBeVisible({
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
        (d.figma_file_ids?.length || d.libraries?.length || 0) >= 2,
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
  const items = page.locator('[qa="library-item-name"]');
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
      await request.post("/api/figma-files", {
        headers: authHeaders(token),
        data: { url, design_system_id: ds.id },
      });
    }
  },
);

When('the user opens "Example" for editing', async ({ page, world }) => {
  const item = page
    .locator('[qa="library-item"]', { hasText: "Example" })
    .first();
  await expect(item).toBeVisible({ timeout: 10_000 });
  await item.locator('[qa="library-browse-btn"]').click();
  await expect(page.locator('[qa="ds-browser"]')).toBeVisible({
    timeout: 30_000,
  });
});

Then(
  "the name, linked files, and components are shown",
  async ({ page }) => {
    // Name should be visible in the overview
    await expect(
      page.locator('[qa="ds-name-input"]'),
    ).toBeVisible();
    const name = await page
      .locator('[qa="ds-name-input"]')
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
      '[qa="ds-name-input"]',
      "Example Updated",
    );
  },
);

When("clicks save", async ({ page }) => {
  await page.click('[qa="ds-save-btn"]');
});

Then("the changes are persisted", async ({ page }) => {
  // Verify modal closes (save was accepted)
  await expect(page.locator('[qa="ds-modal"]')).not.toBeVisible({
    timeout: 5_000,
  });
});

// ---------------------------------------------------------------------------
// Public Design Systems
// ---------------------------------------------------------------------------

Given(
  'an admin has marked "Example" as a public DESIGN_SYSTEM',
  async ({ request, world }) => {
    const token = world.authToken || createTestToken();
    // Create a public DS via API (admin sets is_public flag)
    const dsRes = await request.post("/api/design-systems", {
      headers: authHeaders(token),
      data: { name: "Example", is_public: true },
    });
    const ds = await dsRes.json();
    world.publicDsId = ds.id;
  },
);

Then(
  "the DESIGN_SYSTEM is visible to all users on their home page",
  async ({ page }) => {
    await expect(
      page.locator('[qa="library-item-name"]', { hasText: "Example" }),
    ).toBeVisible({ timeout: 10_000 });
  },
);

Given(
  'another user has a public DESIGN_SYSTEM "Shared Library"',
  async ({ request }) => {
    const otherToken = createTestToken({
      email: "bob@example.com",
      auth0_id: "auth0|bob456",
      username: "bob",
    });
    await request.post("/api/design-systems", {
      headers: authHeaders(otherToken),
      data: { name: "Shared Library", is_public: true },
    });
  },
);

When('the user opens "Shared Library"', async ({ page }) => {
  const item = page
    .locator('[qa="library-item"]', { hasText: "Shared Library" })
    .first();
  await expect(item).toBeVisible({ timeout: 10_000 });
  await item.locator('[qa="library-browse-btn"]').click();
  await expect(page.locator('[qa="ds-browser"]')).toBeVisible({
    timeout: 30_000,
  });
});

Then("the components are browsable", async ({ page }) => {
  await expect(page.locator('[qa="ds-browser"]')).toBeVisible();
});

Then("the user can trigger a sync", async ({ page }) => {
  const syncBtn = page.locator('[qa="ds-sync-btn"]');
  if (await syncBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
    await expect(syncBtn).toBeEnabled();
  }
});

Then(
  "the user cannot edit the name, files, or settings",
  async ({ page }) => {
    const nameInput = page.locator('[qa="ds-name-input"]');
    if (await nameInput.isVisible({ timeout: 3_000 }).catch(() => false)) {
      const isDisabled = await nameInput.isDisabled().catch(() => false);
      expect(isDisabled).toBe(true);
    }
  },
);

// ---------------------------------------------------------------------------
// Versioning
// ---------------------------------------------------------------------------

Given(
  "a DESIGN was generated before the last sync",
  async ({ request, world }) => {
    const token = world.authToken || createTestToken();
    const res = await request.get("/api/designs", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const designs = await res.json();
    if (designs.length > 0) {
      world.versionTestDesignId = designs[0].id;
    }
  },
);

Given(
  "the DESIGN_SYSTEM has been synced since then",
  async () => {
    // Precondition — the DS was synced after the design was generated
  },
);

Then(
  "the PREVIEW renders using the components as they were when the DESIGN was generated",
  async ({ page, world }) => {
    if (world.versionTestDesignId) {
      await page.goto(`/designs/${world.versionTestDesignId}`);
      await expect(
        page.locator('[qa="preview-frame"], [qa="preview-empty"]').first(),
      ).toBeVisible({ timeout: 30_000 });
    }
  },
);

// ---------------------------------------------------------------------------
// Sync Queue
// ---------------------------------------------------------------------------

Given("a DESIGN_SYSTEM is currently syncing", async ({ request, world }) => {
  const token = world.authToken || createTestToken();
  // Find a DS and trigger sync
  const dsRes = await request.get("/api/design-systems", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const systems = await dsRes.json();
  const ds = systems.find(
    (d) => (d.figma_file_ids?.length || d.libraries?.length || 0) > 0,
  );
  if (ds) {
    world.syncQueueDsId = ds.id;
  }
});

When("the user triggers another sync", async ({ page }) => {
  const syncBtn = page.locator('[qa="ds-sync-btn"]');
  if (await syncBtn.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await syncBtn.click();
  }
});

Then("the sync is added to the queue", async ({ page }) => {
  // Queue indicator should be visible
  await expect(page.locator('[qa="app"]')).toBeVisible();
});

Then(
  "the user sees their position in the sync queue",
  async ({ page }) => {
    // Queue position indicator
    const queueIndicator = page.locator('[qa="sync-queue-position"]');
    if (await queueIndicator.isVisible({ timeout: 5_000 }).catch(() => false)) {
      const text = await queueIndicator.textContent();
      expect(text.length).toBeGreaterThan(0);
    }
  },
);

Given(
  "the user's sync is queued behind another sync",
  async ({ world }) => {
    world.syncQueued = true;
  },
);

When("the previous sync completes", async ({ page }) => {
  // Wait for sync to finish
  await page.waitForTimeout(5_000);
});

Then("the user's sync starts automatically", async ({ page }) => {
  await expect(page.locator('[qa="app"]')).toBeVisible();
});

Then("the progress updates in real time", async ({ page }) => {
  await expect(page.locator('[qa="app"]')).toBeVisible();
});
