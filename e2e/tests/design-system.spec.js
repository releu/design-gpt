import { test, expect } from "@playwright/test";

// The two Figma files used throughout the suite.
// They must exist and be accessible with the FIGMA_ACCESS_TOKEN in api/.env.
const FIGMA_URL_ICONS =
  "https://www.figma.com/design/dlYQK7x0jXbn8HCFFvZ0lw/example-icons?node-id=0-1&t=u8U5lP97oul77M9l-1";
const FIGMA_URL_LIB =
  "https://www.figma.com/design/75U91YIrYa65xhYcM0olH5/example-lib?node-id=0-1&t=bDWL7y37QTORZYmv-1";

/**
 * Capture console errors and page errors.
 * Must be called before page.goto() to catch errors during navigation.
 * Returns a getter function so assertions can read the array at test end.
 */
function trackConsoleErrors(page) {
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(`[console.error] ${msg.text()}`);
  });
  page.on("pageerror", (err) => errors.push(`[pageerror] ${err.message}`));
  return () => errors;
}

/** Navigate to home and wait for the sidebar button. */
async function gotoHome(page) {
  await page.goto("/");
  await expect(page.locator("text=New design system")).toBeVisible({ timeout: 10_000 });
}

/** Click "New design system" and wait for the modal. */
async function openModal(page) {
  await page.click("text=New design system");
  await expect(page.locator(".DesignSystemModal")).toBeVisible();
}

/**
 * Add a Figma URL via the native prompt dialog.
 * Waits until the URL item appears in the list before returning.
 */
async function addFigmaUrl(page, url) {
  const countBefore = await page.locator(".DesignSystemModal__url-item").count();
  page.once("dialog", (dialog) => dialog.accept(url));
  await page.click(".DesignSystemModal__source-btn:has-text('+ Figma')");
  await expect(page.locator(".DesignSystemModal__url-item")).toHaveCount(countBefore + 1);
}

// ---------------------------------------------------------------------------
// Quick UI tests — no API calls, no Figma sync.
// These run fast and verify the modal interaction layer.
// ---------------------------------------------------------------------------

test.describe("Design System Modal — add phase", () => {
  let getErrors;

  test.beforeEach(async ({ page }) => {
    getErrors = trackConsoleErrors(page);
    await gotoHome(page);
    await openModal(page);
  });

  test("shows the modal with correct title", async ({ page }) => {
    await expect(page.locator(".DesignSystemModal__title")).toHaveText("New design system");
    expect(getErrors()).toEqual([]);
  });

  test("shows + Figma and + React source buttons", async ({ page }) => {
    await expect(page.locator("text=+ Figma")).toBeVisible();
    await expect(page.locator("text=+ React")).toBeVisible();
    expect(getErrors()).toEqual([]);
  });

  test("+ React button is disabled", async ({ page }) => {
    await expect(page.locator(".DesignSystemModal__source-btn_disabled")).toContainText("+ React");
    expect(getErrors()).toEqual([]);
  });

  test("adds a Figma URL to the list via prompt dialog", async ({ page }) => {
    page.once("dialog", (dialog) => dialog.accept(FIGMA_URL_ICONS));
    await page.click("text=+ Figma");
    await expect(page.locator(".DesignSystemModal__url-list")).toBeVisible();
    await expect(page.locator(".DesignSystemModal__url-item")).toHaveCount(1);
    expect(getErrors()).toEqual([]);
  });

  test("dismissing the prompt does not add a URL", async ({ page }) => {
    page.once("dialog", (dialog) => dialog.dismiss());
    await page.click("text=+ Figma");
    await expect(page.locator(".DesignSystemModal__url-list")).not.toBeVisible();
    expect(getErrors()).toEqual([]);
  });

  test("can add multiple URLs", async ({ page }) => {
    await addFigmaUrl(page, FIGMA_URL_ICONS);
    await addFigmaUrl(page, FIGMA_URL_LIB);
    await expect(page.locator(".DesignSystemModal__url-item")).toHaveCount(2);
    expect(getErrors()).toEqual([]);
  });

  test("can remove a URL from the list", async ({ page }) => {
    await addFigmaUrl(page, FIGMA_URL_ICONS);
    await page.click(".DesignSystemModal__url-remove");
    await expect(page.locator(".DesignSystemModal__url-item")).toHaveCount(0);
    expect(getErrors()).toEqual([]);
  });

  test("Import button appears only after a URL is added", async ({ page }) => {
    await expect(page.locator(".DesignSystemModal__do-import")).not.toBeVisible();
    await addFigmaUrl(page, FIGMA_URL_ICONS);
    await expect(page.locator(".DesignSystemModal__do-import")).toBeVisible();
    expect(getErrors()).toEqual([]);
  });

  test("closes when clicking the × button", async ({ page }) => {
    await page.click(".DesignSystemModal__close");
    await expect(page.locator(".DesignSystemModal")).not.toBeVisible();
    expect(getErrors()).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// Full integration test — real Figma API, real sync pipeline.
//
// DB starts with only the alice user (no pre-loaded library fixtures).
// The test drives the complete "new design system" flow:
//   add URLs → import → watch progress → browse result
//
// This test can take several minutes while Figma syncs.
// ---------------------------------------------------------------------------

test.describe("Design System — full Figma import", () => {
  // The Figma sync runs synchronously inside the POST /sync request (inline
  // queue adapter in E2E test mode). The test budget covers the sync duration;
  // individual assertions need no special timeouts because the browser phase
  // appears within seconds once the sync request returns.
  test.setTimeout(600_000);

  test("imports two Figma files and shows components in the browser", async ({ page }) => {
    const getErrors = trackConsoleErrors(page);

    // 1. Load home page
    await gotoHome(page);

    // 2. Open the modal and add both Figma file URLs
    await openModal(page);
    await addFigmaUrl(page, FIGMA_URL_ICONS);
    await addFigmaUrl(page, FIGMA_URL_LIB);

    // 3. Start the import
    await page.click(".DesignSystemModal__do-import");

    // 4. Importing phase must appear immediately with a progress bar and description.
    //    The sync runs inline, so the Vue component shows this phase while the
    //    two POST /sync requests are in flight.
    await expect(page.locator(".DesignSystemModal__importing")).toBeVisible();
    await expect(page.locator(".ProgressBar")).toBeVisible();
    await expect(page.locator(".DesignSystemModal__importing-desc")).toBeVisible();
    const desc = await page.locator(".DesignSystemModal__importing-desc").textContent();
    expect(desc?.trim().length).toBeGreaterThan(0);

    // 5. After both inline syncs complete the first poll returns "ready" and
    //    the browser phase appears within seconds. The long timeout here covers
    //    the sync duration itself (real Figma API), not UI rendering.
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({ timeout: 600_000 });

    // 6. Both Figma file names must appear as menu subtitles — not raw URLs.
    const subtitles = page.locator(".DesignSystemModal__menu-subtitle");
    await expect(subtitles).toHaveCount(2);
    const subtitleTexts = await subtitles.allTextContents();
    for (const name of subtitleTexts) {
      expect(name.trim().length).toBeGreaterThan(0);
      expect(name).not.toContain("figma.com");
    }

    // 7. At least one component must be listed under the files.
    //    (First menu item is "Overview", items from index 1 onwards are components.)
    await expect(page.locator(".DesignSystemModal__menu-item").nth(1)).toBeVisible();

    expect(getErrors()).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// Create design system from an already-imported library.
//
// This test runs after the full import above, so the library is already
// in the DB with status "ready". The sync action skips re-syncing it, so
// the browser phase appears within the first poll cycle (~2s).
//
// The test drives the "Create design system" feature end to end:
//   import (fast) → browser phase → create → sidebar updated
//
// FAILS until the Create button and sidebar refresh are implemented.
// ---------------------------------------------------------------------------

test.describe("Design System — create from existing library", () => {
  test.setTimeout(600_000); // covers initial sync if library not yet imported

  test("creates a named design system and shows it in the sidebar", async ({ page }) => {
    const getErrors = trackConsoleErrors(page);

    // 1. Load home — sidebar starts empty (no design systems yet)
    await gotoHome(page);
    await expect(page.locator(".LibrarySelector__item")).toHaveCount(0);

    // 2. Open modal and add one Figma file (already imported — sync is skipped)
    await openModal(page);
    await addFigmaUrl(page, FIGMA_URL_LIB);
    await page.click(".DesignSystemModal__do-import");

    // 3. Browser phase appears (fast: first poll returns "ready" immediately)
    await expect(page.locator(".DesignSystemModal__browser")).toBeVisible({ timeout: 600_000 });

    // 4. A "Create design system" button must be visible in the browser phase
    await expect(page.locator(".DesignSystemModal__create")).toBeVisible();

    // 5. Click it — modal should close and design system should be saved
    await page.click(".DesignSystemModal__create");
    await expect(page.locator(".DesignSystemModal")).not.toBeVisible({ timeout: 5_000 });

    // 6. The new design system appears in the sidebar
    await expect(page.locator(".LibrarySelector__item")).toHaveCount(1);

    expect(getErrors()).toEqual([]);
  });
});
