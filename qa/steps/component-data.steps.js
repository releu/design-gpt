import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Helper: find a ready library and its components via API
// ---------------------------------------------------------------------------

async function findReadyLibraryComponents(request) {
  const token = createTestToken();
  const libRes = await request.get("/api/component-libraries", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const libs = await libRes.json();
  const readyLib = libs.find((l) => l.status === "ready");
  if (!readyLib) return null;

  const compRes = await request.get(
    `/api/component-libraries/${readyLib.id}/components`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const compData = await compRes.json();
  return { library: readyLib, components: compData };
}

// ---------------------------------------------------------------------------
// Given: get component/component-set from a ready library
// ---------------------------------------------------------------------------

Given(
  "I have a component from a ready library",
  async ({ request, world }) => {
    const data = await findReadyLibraryComponents(request);
    if (!data) {
      console.log("[qa] No ready library found -- component data tests may fail");
      world.componentId = 999999;
      return;
    }

    // Find a standalone component or default variant
    const comps = data.components.components || [];
    const sets = data.components.component_sets || [];

    if (comps.length > 0) {
      world.componentId = comps[0].id;
    } else if (sets.length > 0 && sets[0].variants && sets[0].variants.length > 0) {
      // Use default variant as component
      world.componentId = sets[0].variants[0].id;
    } else {
      world.componentId = 999999;
    }
    world.libraryId = data.library.id;
    console.log(`[qa] Using component id: ${world.componentId}`);
  },
);

Given(
  "I have a component set from a ready library",
  async ({ request, world }) => {
    const data = await findReadyLibraryComponents(request);
    if (!data) {
      world.componentSetId = 999999;
      return;
    }

    const sets = data.components.component_sets || [];
    world.componentSetId = sets.length > 0 ? sets[0].id : 999999;
    world.libraryId = data.library.id;
    console.log(`[qa] Using component set id: ${world.componentSetId}`);
  },
);

Given(
  "I have a component id from a ready library",
  async ({ request, world }) => {
    const data = await findReadyLibraryComponents(request);
    if (!data) {
      world.componentId = 999999;
      return;
    }

    const comps = data.components.components || [];
    const sets = data.components.component_sets || [];

    if (comps.length > 0) {
      world.componentId = comps[0].id;
    } else if (sets.length > 0 && sets[0].variants && sets[0].variants.length > 0) {
      world.componentId = sets[0].variants[0].id;
    } else {
      world.componentId = 999999;
    }
    console.log(`[qa] Using component id for figma json: ${world.componentId}`);
  },
);

Given(
  "I have a component set id from a ready library",
  async ({ request, world }) => {
    const data = await findReadyLibraryComponents(request);
    if (!data) {
      world.componentSetId = 999999;
      return;
    }

    const sets = data.components.component_sets || [];
    world.componentSetId = sets.length > 0 ? sets[0].id : 999999;
    console.log(`[qa] Using component set id for figma json: ${world.componentSetId}`);
  },
);

// ---------------------------------------------------------------------------
// Visual Diff steps
// ---------------------------------------------------------------------------

When(
  "I send an authenticated GET to the component visual diff",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.get(
      `/api/components/${world.componentId}/visual_diff`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send an authenticated GET to the component screenshots with type {string}",
  async ({ request, world }, type) => {
    const token = createTestToken();
    world.apiResponse = await request.get(
      `/api/components/${world.componentId}/screenshots/${type}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

// ---------------------------------------------------------------------------
// SVG Asset steps
// ---------------------------------------------------------------------------

When(
  "I send an authenticated GET to the component svg",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.get(
      `/api/components/${world.componentId}/svg`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

When(
  "I send an authenticated GET to the component set svg",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.get(
      `/api/component-sets/${world.componentSetId}/svg`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

When(
  "I send an authenticated GET to the component html preview",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.get(
      `/api/components/${world.componentId}/html_preview`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
  },
);

// ---------------------------------------------------------------------------
// Figma JSON steps
// ---------------------------------------------------------------------------

When(
  "I send a plain GET to the component figma json",
  async ({ request, world }) => {
    world.apiResponse = await request.get(
      `/api/components/${world.componentId}/figma_json`,
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

When(
  "I send a plain GET to the component set figma json",
  async ({ request, world }) => {
    world.apiResponse = await request.get(
      `/api/component-sets/${world.componentSetId}/figma_json`,
    );
    try {
      world.apiResponseBody = await world.apiResponse.json();
    } catch {
      world.apiResponseBody = null;
    }
  },
);

// ---------------------------------------------------------------------------
// Custom component CRUD steps
// ---------------------------------------------------------------------------

Given(
  "I have uploaded a custom component to the created library",
  async ({ request, world }) => {
    const token = createTestToken();
    const res = await request.post("/api/custom-components", {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      data: {
        name: "TestCustom",
        react_code:
          "function TestCustom(props) { return React.createElement('div', null, 'test'); }",
        component_library_id: world.createdLibraryId,
      },
    });
    const body = await res.json();
    world.createdCustomComponentId = body.id;
    console.log(`[qa] Created custom component id: ${body.id}`);
  },
);

When(
  "I send an authenticated PATCH to the created custom component with updated code",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.patch(
      `/api/custom-components/${world.createdCustomComponentId}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        data: {
          react_code:
            "function TestCustom(props) { return React.createElement('span', null, 'updated'); }",
        },
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
  "I send an authenticated DELETE to the created custom component",
  async ({ request, world }) => {
    const token = createTestToken();
    world.apiResponse = await request.delete(
      `/api/custom-components/${world.createdCustomComponentId}`,
      {
        headers: { Authorization: `Bearer ${token}` },
      },
    );
  },
);
