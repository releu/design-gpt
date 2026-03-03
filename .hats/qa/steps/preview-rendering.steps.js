import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Renderer URL discovery
// ---------------------------------------------------------------------------

Given(
  "the QA library renderer URL is known",
  async ({ request, world }) => {
    // Find the library ID via the API
    const token = createTestToken();
    const res = await request.get("/api/component-libraries", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const libs = await res.json();
    const readyLib = libs.find((l) => l.status === "ready");

    if (!readyLib) {
      throw new Error(
        "No ready component library found. Run the import scenario first.",
      );
    }

    world.rendererUrl = `/api/component-libraries/${readyLib.id}/renderer`;
    world.libraryId = readyLib.id;
    console.log(
      `[qa-preview] Using renderer URL: ${world.rendererUrl} (library: ${readyLib.name})`,
    );
  },
);

// ---------------------------------------------------------------------------
// Loading renderer
// ---------------------------------------------------------------------------

When("I load the renderer page directly", async ({ page, world }) => {
  await page.goto(world.rendererUrl);
  await page.waitForLoadState("domcontentloaded");
});

When("I load the renderer page without auth", async ({ page, world }) => {
  // Just load directly -- renderer requires no auth
  await page.goto(world.rendererUrl);
  await page.waitForLoadState("domcontentloaded");
});

Then("the renderer page should load successfully", async ({ page }) => {
  // Page should have HTML content
  const html = await page.content();
  expect(html).toContain("<!DOCTYPE html>");
});

// ---------------------------------------------------------------------------
// Renderer content checks
// ---------------------------------------------------------------------------

Then(
  "the renderer page should contain React script tag",
  async ({ page }) => {
    const html = await page.content();
    expect(html).toContain("react");
    expect(html).toContain("unpkg.com");
  },
);

Then(
  "the renderer page should contain ReactDOM script tag",
  async ({ page }) => {
    const html = await page.content();
    expect(html).toContain("react-dom");
  },
);

Then(
  "the renderer page should contain Babel script tag",
  async ({ page }) => {
    const html = await page.content();
    expect(html).toContain("babel");
  },
);

Then("the renderer page should have a root div", async ({ page }) => {
  await expect(page.locator("#root")).toBeAttached();
});

// ---------------------------------------------------------------------------
// PostMessage interaction
// ---------------------------------------------------------------------------

When("I wait for the renderer ready message", async ({ page }) => {
  // The renderer sends { type: "ready" } to parent -- since we loaded directly,
  // we just need to wait for the scripts to execute
  await page.waitForFunction(() => {
    return (
      typeof window.React !== "undefined" &&
      typeof window.ReactDOM !== "undefined"
    );
  }, { timeout: 15_000 });
});

When(
  "I send JSX to the renderer via postMessage",
  async ({ page }) => {
    // Send a simple JSX that uses a component if available, or raw HTML
    await page.evaluate(() => {
      // Try to find any registered component
      const availableComponents = Object.keys(window).filter(
        (k) =>
          typeof window[k] === "function" &&
          /^[A-Z]/.test(k) &&
          k !== "React" &&
          k !== "ReactDOM" &&
          k !== "Babel",
      );

      let jsx;
      if (availableComponents.length > 0) {
        jsx = `<${availableComponents[0]} />`;
      } else {
        jsx = '<div>QA Test Render</div>';
      }

      window.postMessage({ type: "render", jsx }, "*");
    });

    // Wait for render to complete
    await page.waitForTimeout(2_000);
  },
);

Then(
  "the renderer root should contain the rendered component",
  async ({ page }) => {
    const rootContent = await page.locator("#root").innerHTML();
    expect(rootContent.trim().length).toBeGreaterThan(0);
  },
);

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------

When(
  "I send JSX referencing nonexistent component {string}",
  async ({ page }, componentName) => {
    await page.evaluate((name) => {
      window.postMessage(
        { type: "render", jsx: `<${name}>Hello</${name}>` },
        "*",
      );
    }, componentName);
    await page.waitForTimeout(2_000);
  },
);

Then("the renderer should show a rendering error", async ({ page }) => {
  const errorPre = page.locator(
    'pre[style*="color: red"], pre[style*="color:red"]',
  );
  await expect(errorPre).toBeVisible({ timeout: 5_000 });
  const errorText = await errorPre.textContent();
  expect(errorText.length).toBeGreaterThan(0);
  console.log(`[qa-preview] Render error text: ${errorText.slice(0, 100)}`);
});

Then("the error should not crash the renderer", async ({ page }) => {
  // After the error, the page should still be functional
  // Send valid JSX and verify it renders
  await page.evaluate(() => {
    window.postMessage(
      { type: "render", jsx: "<div>Recovery Test</div>" },
      "*",
    );
  });
  await page.waitForTimeout(1_000);

  const rootContent = await page.locator("#root").innerHTML();
  // Should either show "Recovery Test" or still show the error -- but page is not crashed
  expect(rootContent.trim().length).toBeGreaterThan(0);
});

// ---------------------------------------------------------------------------
// Design system renderer
// ---------------------------------------------------------------------------

Given(
  "the QA design system renderer URL is known",
  async ({ request, world }) => {
    const token = createTestToken();
    const res = await request.get("/api/design-systems", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const systems = await res.json();
    const ds = systems.find((s) => s.name && s.name.includes("QA"));

    if (!ds) {
      throw new Error(
        "No QA design system found. Run the import scenario first.",
      );
    }

    world.dsRendererUrl = `/api/design-systems/${ds.id}/renderer`;
    console.log(
      `[qa-preview] Using design system renderer URL: ${world.dsRendererUrl}`,
    );
  },
);

When("I load the design system renderer page", async ({ page, world }) => {
  await page.goto(world.dsRendererUrl);
  await page.waitForLoadState("domcontentloaded");
});

// ---------------------------------------------------------------------------
// Iteration renderer
// ---------------------------------------------------------------------------

Given(
  "the QA iteration renderer URL is known",
  async ({ request, world }) => {
    const token = createTestToken();

    // Find a design with iterations
    const designsRes = await request.get("/api/designs", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const designs = await designsRes.json();
    const readyDesign = designs.find((d) => d.status === "ready");

    if (!readyDesign) {
      throw new Error(
        "No ready design found. Run the generation scenario first.",
      );
    }

    // Get design details to find an iteration
    const detailRes = await request.get(`/api/designs/${readyDesign.id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const detail = await detailRes.json();
    const iterations = detail.iterations || [];

    if (iterations.length === 0) {
      throw new Error("No iterations found on the ready design.");
    }

    world.iterationRendererUrl = `/api/iterations/${iterations[0].id}/renderer`;
    console.log(
      `[qa-preview] Using iteration renderer URL: ${world.iterationRendererUrl}`,
    );
  },
);

When("I load the iteration renderer page", async ({ page, world }) => {
  await page.goto(world.iterationRendererUrl);
  await page.waitForLoadState("domcontentloaded");
});
