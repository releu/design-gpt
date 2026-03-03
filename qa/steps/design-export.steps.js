import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Get current design ID from the URL
// ---------------------------------------------------------------------------

function getDesignIdFromUrl(page) {
  const url = page.url();
  const match = url.match(/\/designs\/(\d+)/);
  if (!match) throw new Error(`Not on a design page: ${url}`);
  return match[1];
}

// ---------------------------------------------------------------------------
// Figma JSON export
// ---------------------------------------------------------------------------

When(
  "I request Figma JSON export for the current design via API",
  async ({ page, request, world }) => {
    const designId = getDesignIdFromUrl(page);
    const token = createTestToken();
    world.exportResponse = await request.get(
      `/api/designs/${designId}/export_figma`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    try {
      world.exportBody = await world.exportResponse.json();
    } catch {
      world.exportBody = null;
    }
  },
);

Then(
  "the export response should contain field {string}",
  async ({ world }, field) => {
    expect(world.exportBody).toHaveProperty(field);
  },
);

// ---------------------------------------------------------------------------
// React project export
// ---------------------------------------------------------------------------

When(
  "I request React export for the current design via API",
  async ({ page, request, world }) => {
    const designId = getDesignIdFromUrl(page);
    const token = createTestToken();
    world.exportResponse = await request.get(
      `/api/designs/${designId}/export_react`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

Then(
  "the export response content type should be {string}",
  async ({ world }, contentType) => {
    const headers = world.exportResponse.headers();
    const ct = headers["content-type"] || "";
    expect(ct).toContain(contentType);
  },
);

// ---------------------------------------------------------------------------
// Image export
// ---------------------------------------------------------------------------

When(
  "I request image export for the current design via API",
  async ({ page, request, world }) => {
    const designId = getDesignIdFromUrl(page);
    const token = createTestToken();
    world.imageExportResponse = await request.get(
      `/api/designs/${designId}/export_image`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

Then(
  "the image export response status should be either 200 or 404",
  async ({ world }) => {
    const status = world.imageExportResponse.status();
    expect([200, 404]).toContain(status);
    console.log(`[qa-export] Image export returned status: ${status}`);
  },
);

// ---------------------------------------------------------------------------
// Duplicate
// ---------------------------------------------------------------------------

When(
  "I duplicate the current design via API",
  async ({ page, request, world }) => {
    const designId = getDesignIdFromUrl(page);
    const token = createTestToken();
    world.duplicateResponse = await request.post(
      `/api/designs/${designId}/duplicate`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    try {
      world.duplicateBody = await world.duplicateResponse.json();
    } catch {
      world.duplicateBody = null;
    }
  },
);

Then(
  "the duplicate response should contain a new design id",
  async ({ world }) => {
    expect(world.duplicateBody).toHaveProperty("id");
    expect(typeof world.duplicateBody.id).toBe("number");
  },
);

Then(
  "the duplicate response should have status 201",
  async ({ world }) => {
    expect(world.duplicateResponse.status()).toBe(201);
  },
);
