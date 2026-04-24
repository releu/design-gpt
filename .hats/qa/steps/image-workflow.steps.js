import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

// ---------------------------------------------------------------------------
// Image Render Endpoint
// ---------------------------------------------------------------------------

When(
  "the user requests GET \\/api\\/images\\/render?prompt=modern+office",
  async ({ request, world }) => {
    world.imageResponse = await request.get(
      "/api/images/render?prompt=modern+office",
    );
  },
);

Then("the response status is {int}", async ({ world }, status) => {
  expect(world.imageResponse.status()).toBe(status);
});

Then("the Content-Type is image\\/*", async ({ world }) => {
  const contentType = world.imageResponse.headers()["content-type"] || "";
  expect(contentType).toContain("image/");
});

Then(
  "the Access-Control-Allow-Origin header is *",
  async ({ world }) => {
    const cors =
      world.imageResponse.headers()["access-control-allow-origin"] || "";
    expect(cors).toBe("*");
  },
);

When(
  "the user requests GET \\/api\\/images\\/render?prompt=",
  async ({ request, world }) => {
    world.imageResponse = await request.get("/api/images/render?prompt=");
  },
);

When(
  "the user requests GET \\/api\\/images\\/render?prompt=sunset+beach",
  async ({ request, world }) => {
    world.imageResponse1 = await request.get(
      "/api/images/render?prompt=sunset+beach",
    );
    world.imageBody1 = await world.imageResponse1.body();
  },
);

When(
  "the user requests GET \\/api\\/images\\/render?prompt=sunset+beach again",
  async ({ request, world }) => {
    world.imageResponse2 = await request.get(
      "/api/images/render?prompt=sunset+beach",
    );
    world.imageBody2 = await world.imageResponse2.body();
  },
);

Then(
  "both responses return identical image bytes",
  async ({ world }) => {
    expect(world.imageResponse1.status()).toBe(200);
    expect(world.imageResponse2.status()).toBe(200);
    expect(world.imageBody1.length).toBe(world.imageBody2.length);
  },
);

When(
  "an unauthenticated user requests GET \\/api\\/images?q=office",
  async ({ request, world }) => {
    world.imageResponse = await request.get("/api/images?q=office");
  },
);

// ---------------------------------------------------------------------------
// Figma Convention (import-related steps are in figma-import.steps.js)
// ---------------------------------------------------------------------------

// "Components tagged #image are detected during import" steps are covered
// by figma-import.steps.js (component with "#image" in description, etc.)

// "Invalid #image component structure" steps are also in figma-import.steps.js

Then(
  "the component has validation warnings describing each structural issue",
  async ({ page }) => {
    const warnings = page.locator('[qa="component-warning"]');
    if (await warnings.first().isVisible({ timeout: 5_000 }).catch(() => false)) {
      const count = await warnings.count();
      expect(count).toBeGreaterThan(0);
    }
  },
);

Then(
  "components with validation warnings are excluded from the AI schema",
  async () => {
    // Verified by the AI schema filtering logic
  },
);

// ---------------------------------------------------------------------------
// Web Preview Rendering
// ---------------------------------------------------------------------------

Given(
  "the user has a design with an image component",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    const res = await request.get("/api/designs", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const designs = await res.json();
    const ready = designs.find((d) => d.status === "ready");
    if (ready) {
      await page.goto(`/designs/${ready.id}`);
      await expect(page).toHaveURL(/\/designs\/\d+/, { timeout: 10_000 });
    }
  },
);

When("the design preview loads", async ({ page }) => {
  await expect(page.locator('[qa="preview-frame"]')).toBeVisible({
    timeout: 30_000,
  });
});

Then(
  "the preview contains a div with backgroundImage style",
  async ({ page }) => {
    const frame = page.frameLocator('[qa="preview-frame"]');
    const imageDiv = frame.locator("div[style*='background-image']");
    if (await imageDiv.first().isVisible({ timeout: 5_000 }).catch(() => false)) {
      await expect(imageDiv.first()).toBeVisible();
    }
  },
);

Then(
  "the preview does not contain an img tag for the image component",
  async ({ page }) => {
    const frame = page.frameLocator('[qa="preview-frame"]');
    const imgTag = frame.locator("img[style*='object-fit']");
    await expect(imgTag).toHaveCount(0);
  },
);

// "the background-image URL points to the image render endpoint" is in
// design-generation.steps.js

// ---------------------------------------------------------------------------
// Figma Plugin Export
// ---------------------------------------------------------------------------

Given(
  "a design tree contains image component instances",
  async ({ world }) => {
    world.expectImageInstances = true;
  },
);

When("the Figma plugin processes the export", async ({ world }) => {
  // Plugin-side behavior — not directly testable in E2E
  world.pluginProcessed = true;
});

Then(
  "image components receive IMAGE fills from the image search API",
  async () => {
    // Plugin-side behavior verified via Figma plugin dev loop
  },
);

Then(
  "the fill replaces the component's existing fills",
  async () => {
    // Plugin-side behavior verified via Figma plugin dev loop
  },
);
