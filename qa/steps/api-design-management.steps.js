import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Create a design via API (for subsequent operations)
// ---------------------------------------------------------------------------

Given(
  "I have created a design via API with prompt {string}",
  async ({ request, world }, prompt) => {
    // First we need a component library to link to the design.
    // Create a dummy library so the design can be created.
    const createLibRes = await request.post("/api/component-libraries", {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: { url: `https://www.figma.com/design/dummydesign${Date.now()}/dummy` },
    });
    const lib = await createLibRes.json();

    const res = await request.post("/api/designs", {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: {
        design: {
          prompt,
          component_library_ids: [lib.id],
        },
      },
    });
    const body = await res.json();
    world.createdDesignId = body.id;
  },
);

// ---------------------------------------------------------------------------
// Create a library via API (for duplicate/custom component tests)
// ---------------------------------------------------------------------------

Given(
  "I have created a library with url {string}",
  async ({ request, world }, url) => {
    const res = await request.post("/api/component-libraries", {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: { url },
    });
    const body = await res.json();
    world.createdLibraryId = body.id;
  },
);
