import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Logged in user
// ---------------------------------------------------------------------------

Given("the user is logged in as alice", async ({ world }) => {
  world.authToken = createTestToken();
});

// ---------------------------------------------------------------------------
// Custom user token
// ---------------------------------------------------------------------------

Given(
  "a new user token for {string} with email {string}",
  async ({ world }, auth0Id, email) => {
    world.authToken = createTestToken({ auth0_id: auth0Id, email });
  },
);

// ---------------------------------------------------------------------------
// Authenticated API calls
// ---------------------------------------------------------------------------

When(
  "I send an authenticated GET to {string}",
  async ({ request, world }, urlPath) => {
    world.apiResponse = await request.get(urlPath, {
      headers: { Authorization: `Bearer ${world.authToken}` },
    });
  },
);

When(
  "I send an unauthenticated GET to {string}",
  async ({ request, world }, urlPath) => {
    world.apiResponse = await request.get(urlPath);
  },
);

When(
  "I send a GET to {string} with an invalid token",
  async ({ request, world }, urlPath) => {
    world.apiResponse = await request.get(urlPath, {
      headers: { Authorization: "Bearer invalid.token.here" },
    });
  },
);

When(
  "I send a GET to {string} with an expired token",
  async ({ request, world }, urlPath) => {
    const expiredToken = createTestToken({
      exp: Math.floor(Date.now() / 1000) - 3600,
    });
    world.apiResponse = await request.get(urlPath, {
      headers: { Authorization: `Bearer ${expiredToken}` },
    });
  },
);

When(
  "I send a plain GET to {string}",
  async ({ request, world }, urlPath) => {
    world.apiResponse = await request.get(urlPath);
  },
);

When(
  "I send an authenticated POST to {string}",
  async ({ request, world }, urlPath) => {
    world.apiResponse = await request.post(urlPath, {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
      },
    });
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated POST to {string} with body:",
  async ({ request, world }, urlPath, bodyStr) => {
    // Replace __LIBRARY_ID__ placeholder if present
    let body = bodyStr;
    if (world.createdLibraryId) {
      body = body.replace(/"__LIBRARY_ID__"/g, String(world.createdLibraryId));
    }
    world.apiResponse = await request.post(urlPath, {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: JSON.parse(body),
    });
    // Store response body for later assertions
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated PATCH to the created design with body:",
  async ({ request, world }, bodyStr) => {
    const designId = world.createdDesignId;
    world.apiResponse = await request.patch(`/api/designs/${designId}`, {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: JSON.parse(bodyStr),
    });
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated DELETE to the created design",
  async ({ request, world }) => {
    const designId = world.createdDesignId;
    world.apiResponse = await request.delete(`/api/designs/${designId}`, {
      headers: { Authorization: `Bearer ${world.authToken}` },
    });
  },
);

When(
  "I send an authenticated PATCH to {string} with body:",
  async ({ request, world }, urlPath, bodyStr) => {
    world.apiResponse = await request.patch(urlPath, {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: JSON.parse(bodyStr),
    });
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated POST to sync the created library",
  async ({ request, world }) => {
    world.apiResponse = await request.post(
      `/api/component-libraries/${world.createdLibraryId}/sync`,
      {
        headers: { Authorization: `Bearer ${world.authToken}` },
      },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated GET to the created library",
  async ({ request, world }) => {
    world.apiResponse = await request.get(
      `/api/component-libraries/${world.createdLibraryId}`,
      {
        headers: { Authorization: `Bearer ${world.authToken}` },
      },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated GET to the created library components",
  async ({ request, world }) => {
    world.apiResponse = await request.get(
      `/api/component-libraries/${world.createdLibraryId}/components`,
      {
        headers: { Authorization: `Bearer ${world.authToken}` },
      },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated GET to the created design",
  async ({ request, world }) => {
    world.apiResponse = await request.get(
      `/api/designs/${world.createdDesignId}`,
      {
        headers: { Authorization: `Bearer ${world.authToken}` },
      },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated POST to duplicate the created design",
  async ({ request, world }) => {
    world.apiResponse = await request.post(
      `/api/designs/${world.createdDesignId}/duplicate`,
      {
        headers: { Authorization: `Bearer ${world.authToken}` },
      },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I create a design via API with prompt {string} and the created library",
  async ({ request, world }, prompt) => {
    world.apiResponse = await request.post("/api/designs", {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: {
        design: {
          prompt,
          component_library_ids: [world.createdLibraryId],
        },
      },
    });
    try {
      world.apiResponseBody = await world.apiResponse.json();
      if (world.apiResponseBody && world.apiResponseBody.id) {
        world.createdDesignId = world.apiResponseBody.id;
      }
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I create a design system via API with name {string} and the created library",
  async ({ request, world }, name) => {
    world.apiResponse = await request.post("/api/design-systems", {
      headers: {
        Authorization: `Bearer ${world.authToken}`,
        "Content-Type": "application/json",
      },
      data: {
        name,
        component_library_ids: [world.createdLibraryId],
      },
    });
    try {
      world.apiResponseBody = await world.apiResponse.json();
      if (world.apiResponseBody && world.apiResponseBody.id) {
        world.createdDesignSystemId = world.apiResponseBody.id;
      }
    } catch {
      world.apiResponseBody = null;
    }
  },
);

// ---------------------------------------------------------------------------
// Assertions on API responses
// ---------------------------------------------------------------------------

Then("the API response status should be 200", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(200);
});

Then("the API response status should be 201", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(201);
});

Then("the API response status should be 204", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(204);
});

Then("the API response status should be 401", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(401);
});

Then("the API response status should be 404", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(404);
});

Then("the API response status should not be 201", async ({ world }) => {
  expect(world.apiResponse.status()).not.toBe(201);
});

Then("the API response status should not be 404", async ({ world }) => {
  expect(world.apiResponse.status()).not.toBe(404);
});

Then("the API response status should not be 500", async ({ world }) => {
  expect(world.apiResponse.status()).not.toBe(500);
});

Then("the API response status should be 400", async ({ world }) => {
  expect(world.apiResponse.status()).toBe(400);
});

Then("the response content type should be JSON", async ({ world }) => {
  const ct = world.apiResponse.headers()["content-type"] || "";
  expect(ct).toContain("json");
});

Then("the API response body should be a JSON array", async ({ world }) => {
  const body = world.apiResponseBody || (await world.apiResponse.json());
  expect(Array.isArray(body)).toBe(true);
});

Then(
  "the API response body should contain field {string}",
  async ({ world }, field) => {
    const body = world.apiResponseBody || (await world.apiResponse.json());
    expect(body).toHaveProperty(field);
  },
);

Then(
  "the API response body should contain {string}",
  async ({ world }, text) => {
    const bodyText = await world.apiResponse.text();
    expect(bodyText).toContain(text);
  },
);

Then(
  "the API response body should contain the same library id",
  async ({ world }) => {
    const body = world.apiResponseBody || (await world.apiResponse.json());
    expect(body.id).toBe(world.createdLibraryId);
  },
);

// ---------------------------------------------------------------------------
// UI auth assertions
// ---------------------------------------------------------------------------

When("I navigate to the home page without auth", async ({ page }) => {
  // Clear any stored auth state, visit as unauthenticated user
  await page.goto("/");
});

Then("the sign-in prompt should be visible", async ({ page }) => {
  // Auth0 login button or sign-in message should be visible
  const signIn = page.locator(
    "[class*='login'], [class*='sign-in'], [class*='auth'], [class*='Login'], [class*='SignIn'], button:has-text('Log In'), button:has-text('Sign In')",
  );
  await expect(signIn.first()).toBeVisible({ timeout: 15_000 });
});

Then("no application content should be shown", async ({ page }) => {
  // The Prompt area and LibrarySelector should NOT be visible when unauthenticated
  const prompt = page.locator(".Prompt");
  await expect(prompt).not.toBeVisible({ timeout: 5_000 });
});

Then("the prompt area should be visible", async ({ page }) => {
  await expect(page.locator(".Prompt")).toBeVisible({ timeout: 10_000 });
});

Then("the design system selector should be visible", async ({ page }) => {
  await expect(page.locator(".LibrarySelector")).toBeVisible({
    timeout: 10_000,
  });
});
