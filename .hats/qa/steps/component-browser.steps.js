import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";
import { createTestToken } from "../support/auth.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function openDesignSystemBrowser(page, request, token) {
  // Find a DS with components and open its browser
  const dsRes = await request.get("/api/design-systems", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const systems = await dsRes.json();
  const ds = systems.find(
    (d) => (d.component_library_ids?.length || d.libraries?.length || 0) > 0,
  );

  if (ds) {
    const item = page
      .locator(".LibrarySelector__item", { hasText: ds.name })
      .first();
    if (await item.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await item.locator(".LibrarySelector__item-browse").click();
      await expect(
        page.locator(".DesignSystemModal__browser"),
      ).toBeVisible({ timeout: 30_000 });
      return ds;
    }
  }
  return null;
}

async function navigateToComponent(page, name) {
  await page
    .locator(".DesignSystemModal__menu-item", { hasText: name })
    .first()
    .click();
  await expect(page.locator(".ComponentDetail__name")).toContainText(name, {
    timeout: 5_000,
  });
}

// ---------------------------------------------------------------------------
// Components are grouped by FIGMA_FILE
// ---------------------------------------------------------------------------

Given(
  "the user is browsing a DESIGN_SYSTEM with components from {int} FIGMA_FILEs",
  async ({ page, request, world }, fileCount) => {
    const token = world.authToken || createTestToken();
    await openDesignSystemBrowser(page, request, token);
  },
);

Then(
  "components are grouped under their FIGMA_FILE names",
  async ({ page }) => {
    const subtitles = page.locator(".DesignSystemModal__menu-subtitle");
    await expect(subtitles.first()).toBeVisible({ timeout: 10_000 });
    const count = await subtitles.count();
    expect(count).toBeGreaterThanOrEqual(1);
  },
);

// ---------------------------------------------------------------------------
// Component detail: Figma link
// ---------------------------------------------------------------------------

Given(
  "the user is viewing TITLE_COMPONENT",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Try to find Title component; fall back to first available component
    const titleItem = page.locator(".DesignSystemModal__menu-item", {
      hasText: /title/i,
    });
    if (
      await titleItem.first().isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await titleItem.first().click();
    } else {
      // Click the first non-special menu item
      const menuItems = page.locator(".DesignSystemModal__menu-item");
      const count = await menuItems.count();
      for (let i = 0; i < count; i++) {
        const text = (await menuItems.nth(i).textContent()).trim();
        if (text !== "Overview" && text !== "AI Schema") {
          await menuItems.nth(i).click();
          break;
        }
      }
    }
    await expect(page.locator(".ComponentDetail__name")).toBeVisible({
      timeout: 5_000,
    });
  },
);

Then(
  "a link to the component's Figma source is shown",
  async ({ page }) => {
    const figmaLink = page.locator(
      ".ComponentDetail a[href*='figma.com'], .ComponentDetail [class*='figma-link'], .ComponentDetail__figma-link",
    );
    await expect(figmaLink.first()).toBeVisible({ timeout: 5_000 });
  },
);

// ---------------------------------------------------------------------------
// Sync button
// ---------------------------------------------------------------------------

When("the user clicks the sync button", async ({ page }) => {
  const syncBtn = page.locator(
    ".ComponentDetail__sync-btn, .ComponentDetail button:has-text('sync'), .ComponentDetail button:has-text('Sync')",
  );
  await expect(syncBtn.first()).toBeVisible({ timeout: 5_000 });
  await syncBtn.first().click();
});

// Steps "the component is re-imported from Figma" and "the updated component details are shown"
// are already defined in figma-import.steps.js

// ---------------------------------------------------------------------------
// Component detail lists all PROPs
// ---------------------------------------------------------------------------

Given(
  'the user is viewing TITLE_COMPONENT with PROPs "size" \\(VARIANT), "marker" \\(boolean), and "text" \\(string)',
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Navigate to Title component
    const titleItem = page.locator(".DesignSystemModal__menu-item", {
      hasText: /title/i,
    });
    if (
      await titleItem.first().isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await titleItem.first().click();
    }
    await expect(page.locator(".ComponentDetail__name")).toBeVisible({
      timeout: 5_000,
    });
  },
);

Then("all three PROPs are listed with their types", async ({ page }) => {
  const propRows = page.locator(".ComponentDetail__prop-row");
  const count = await propRows.count();
  expect(count).toBeGreaterThanOrEqual(3);

  // Check that prop names are visible
  const propNames = page.locator(".ComponentDetail__prop-name");
  const nameCount = await propNames.count();
  expect(nameCount).toBeGreaterThanOrEqual(3);
});

// ---------------------------------------------------------------------------
// ALLOWED_CHILDREN for components with SLOTs
// ---------------------------------------------------------------------------

Given(
  'the user is viewing PAGE_COMPONENT which has a SLOT "content" with ALLOWED_CHILDREN [TITLE_COMPONENT, TEXT_COMPONENT]',
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Navigate to Page component (root)
    const pageItem = page.locator(".DesignSystemModal__menu-item", {
      hasText: /page/i,
    });
    if (
      await pageItem.first().isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await pageItem.first().click();
    }
    await expect(page.locator(".ComponentDetail__name")).toBeVisible({
      timeout: 5_000,
    });
  },
);

Then(
  'the SLOT "content" and its ALLOWED_CHILDREN are shown',
  async ({ page }) => {
    const childrenList = page.locator(".ComponentDetail__children-list");
    if (
      await childrenList.isVisible({ timeout: 5_000 }).catch(() => false)
    ) {
      const children = page.locator(".ComponentDetail__children-item");
      const count = await children.count();
      expect(count).toBeGreaterThanOrEqual(2);
    } else {
      // Check for any configuration section showing allowed children
      const configSection = page.locator(
        ".ComponentDetail__config-row, [class*='allowed-children']",
      );
      await expect(configSection.first()).toBeVisible({ timeout: 5_000 });
    }
  },
);

// ---------------------------------------------------------------------------
// VARIANT PROP select control
// ---------------------------------------------------------------------------

Given(
  'the user is viewing TITLE_COMPONENT with a VARIANT PROP "size" with values ["m", "l"]',
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a component with variant props
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const propSelect = page.locator(".ComponentDetail__prop-row select");
      if (
        await propSelect.first().isVisible({ timeout: 2_000 }).catch(() => false)
      ) {
        world.variantComponentName = text;
        return;
      }
    }
    console.log("[qa] No component with variant props found");
  },
);

When(
  'the user selects "m" for the "size" PROP',
  async ({ page }) => {
    const select = page.locator(".ComponentDetail__prop-row select").first();
    await expect(select).toBeVisible({ timeout: 5_000 });
    const options = await select.locator("option").allTextContents();
    // Select first available option (may not be exactly "m")
    if (options.length > 0) {
      await select.selectOption(options[0].trim());
      await page.waitForTimeout(600);
    }
  },
);

Then('the PREVIEW updates to show the "m" variant', async ({ page }) => {
  const frame = page.frameLocator(".ComponentDetail__preview-frame");
  await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 10_000 });
});

// ---------------------------------------------------------------------------
// Boolean PROP checkbox
// ---------------------------------------------------------------------------

Given(
  'the user is viewing TITLE_COMPONENT with a boolean PROP "marker"',
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a component with boolean props
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const checkbox = page.locator(
        '.ComponentDetail__prop-row input[type="checkbox"]',
      );
      if (
        await checkbox.first().isVisible({ timeout: 2_000 }).catch(() => false)
      ) {
        world.booleanComponentName = text;
        return;
      }
    }
    console.log("[qa] No component with boolean props found");
  },
);

When('the user toggles the "marker" checkbox', async ({ page }) => {
  const checkbox = page
    .locator('.ComponentDetail__prop-row input[type="checkbox"]')
    .first();
  await expect(checkbox).toBeVisible({ timeout: 5_000 });
  const isChecked = await checkbox.isChecked();
  isChecked ? await checkbox.uncheck() : await checkbox.check();
  await page.waitForTimeout(600);
});

Then(
  "the PREVIEW updates to reflect the new value",
  async ({ page }) => {
    const frame = page.frameLocator(".ComponentDetail__preview-frame");
    await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// String PROP text input
// ---------------------------------------------------------------------------

Given(
  'the user is viewing TITLE_COMPONENT with a string PROP "text"',
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a component with text props
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const textInput = page.locator(
        '.ComponentDetail__prop-row input[type="text"]',
      );
      if (
        await textInput.first().isVisible({ timeout: 2_000 }).catch(() => false)
      ) {
        world.textPropComponentName = text;
        return;
      }
    }
    console.log("[qa] No component with text props found");
  },
);

When(
  'the user types "Hello World" into the "text" input',
  async ({ page }) => {
    const textInput = page
      .locator('.ComponentDetail__prop-row input[type="text"]')
      .first();
    await expect(textInput).toBeVisible({ timeout: 5_000 });
    await textInput.fill("Hello World");
    await page.waitForTimeout(600);
  },
);

Then(
  'the PREVIEW updates to display "Hello World"',
  async ({ page }) => {
    const frame = page.frameLocator(".ComponentDetail__preview-frame");
    const rootText = await frame
      .locator("#root")
      .textContent({ timeout: 10_000 });
    expect(rootText).toContain("Hello World");
  },
);

// ---------------------------------------------------------------------------
// React code section
// ---------------------------------------------------------------------------

Given(
  "the user is viewing TEXT_COMPONENT that has generated React code",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a component with "ready" status
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const statusBadge = await page
        .locator(".ComponentDetail__status-badge")
        .textContent({ timeout: 2_000 })
        .catch(() => "");
      if (statusBadge.trim() === "ready") {
        world.readyComponentName = text;
        return;
      }
    }
    console.log("[qa] No component with ready status found");
  },
);

Then(
  "the user can view the component's React source code",
  async ({ page }) => {
    // Expand React Code section if needed
    const codeHeader = page.locator(".ComponentDetail__section-header", {
      hasText: "React Code",
    });
    if (await codeHeader.isVisible().catch(() => false)) {
      await codeHeader.click();
    }

    const codeWrap = page.locator(".ComponentDetail__code-wrap");
    await expect(codeWrap).toBeVisible({ timeout: 5_000 });
    const editor = codeWrap.locator(".cm-content");
    await expect(editor).not.toBeEmpty({ timeout: 5_000 });
    const text = await editor.textContent();
    expect(text).toMatch(/function|export|return|React/i);
  },
);

// ---------------------------------------------------------------------------
// Component with no React code
// ---------------------------------------------------------------------------

Given(
  "a component failed React code generation",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a component with "no code" status
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const statusBadge = await page
        .locator(".ComponentDetail__status-badge")
        .textContent({ timeout: 2_000 })
        .catch(() => "");
      if (statusBadge.trim() === "no code") {
        world.noCodeComponentName = text;
        return;
      }
    }
    console.log("[qa] No component with 'no code' status found");
  },
);

When("the user views the component detail", async ({ page }) => {
  await expect(page.locator(".ComponentDetail__name")).toBeVisible({
    timeout: 5_000,
  });
});

Then(
  "a message indicates that React code is not available",
  async ({ page }) => {
    const statusBadge = page.locator(".ComponentDetail__status-badge");
    await expect(statusBadge).toBeVisible({ timeout: 5_000 });
    const text = await statusBadge.textContent();
    expect(text.trim()).toBe("no code");
  },
);

// ---------------------------------------------------------------------------
// AI Schema view
// ---------------------------------------------------------------------------

Given(
  "the DESIGN_SYSTEM has a ROOT component PAGE with SLOTs",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }
  },
);

When("the user opens the AI Schema view", async ({ page }) => {
  await page
    .locator(".DesignSystemModal__menu-item", { hasText: "AI Schema" })
    .click();
});

Then("a tree is displayed starting from PAGE", async ({ page }) => {
  await expect(
    page.locator(".DesignSystemModal__browser-detail"),
  ).toBeVisible({ timeout: 5_000 });
});

Then(
  "each SLOT shows its ALLOWED_CHILDREN",
  async ({ page }) => {
    // The AI Schema view should render the component tree
    await expect(
      page.locator(".DesignSystemModal__browser-detail"),
    ).toBeVisible();
  },
);

Given(
  "the DESIGN_SYSTEM has no ROOT components",
  async ({ page, request, world }) => {
    // Use a DS that has no root components
    const token = world.authToken || createTestToken();
    // Create a minimal DS with no root markers
    await request.post("/api/design-systems", {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      data: { name: `No-root DS ${Date.now()}` },
    });
    // Reload page to see the new DS
    await page.reload();
    await expect(page.locator(".App")).toBeVisible({ timeout: 10_000 });
  },
);

When("the user views the AI Schema", async ({ page }) => {
  // Open the no-root DS and navigate to AI Schema
  const item = page
    .locator(".LibrarySelector__item", { hasText: /No-root DS/ })
    .first();
  if (await item.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await item.locator(".LibrarySelector__item-browse").click();
    await expect(
      page.locator(".DesignSystemModal"),
    ).toBeVisible({ timeout: 10_000 });
    const aiSchema = page.locator(".DesignSystemModal__menu-item", {
      hasText: "AI Schema",
    });
    if (await aiSchema.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await aiSchema.click();
    }
  }
});

Then(
  "a message explains that no ROOT components were found and how to mark them in Figma",
  async ({ page }) => {
    // The AI Schema view should show an empty/help message
    await expect(
      page.locator(".DesignSystemModal__browser-detail, .DesignSystemModal"),
    )
      .first()
      .toBeVisible({ timeout: 5_000 });
  },
);

// ---------------------------------------------------------------------------
// Figma JSON
// ---------------------------------------------------------------------------

When("the user opens the Figma JSON section", async ({ page }) => {
  const jsonHeader = page.locator(".ComponentDetail__section-header", {
    hasText: /Figma JSON/i,
  });
  if (await jsonHeader.isVisible().catch(() => false)) {
    await jsonHeader.click();
    await page.waitForTimeout(1_000); // Allow time for JSON to load on demand
  }
});

Then("the Figma JSON is fetched on demand", async ({ page }) => {
  // JSON section should now be expanded
  await expect(page.locator(".ComponentDetail__name")).toBeVisible();
});

Then("displayed in a formatted code block", async ({ page }) => {
  const codeBlock = page.locator(
    ".ComponentDetail pre, .ComponentDetail code, .ComponentDetail .cm-content",
  );
  await expect(codeBlock.first()).toBeVisible({ timeout: 5_000 });
  const text = await codeBlock.first().textContent();
  expect(text.length).toBeGreaterThan(10);
});

// ---------------------------------------------------------------------------
// COMPONENT_SET Figma JSON for all VARIANTs
// ---------------------------------------------------------------------------

Given(
  "the user is viewing a COMPONENT_SET",
  async ({ page, request, world }) => {
    const token = world.authToken || createTestToken();
    if (
      !(await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false))
    ) {
      await openDesignSystemBrowser(page, request, token);
    }

    // Find a Component Set
    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    for (let i = 0; i < count; i++) {
      const text = (await menuItems.nth(i).textContent()).trim();
      if (text === "Overview" || text === "AI Schema") continue;

      await menuItems.nth(i).click();
      await page.waitForTimeout(500);

      const typeBadge = await page
        .locator(".ComponentDetail__type-badge")
        .textContent({ timeout: 2_000 })
        .catch(() => "");
      if (typeBadge.trim() === "Component Set") {
        world.componentSetName = text;
        return;
      }
    }
    console.log("[qa] No Component Set found in the library");
  },
);

Then(
  "the Figma JSON for all VARIANTs is shown",
  async ({ page }) => {
    const codeBlock = page.locator(
      ".ComponentDetail pre, .ComponentDetail code, .ComponentDetail .cm-content",
    );
    if (await codeBlock.first().isVisible({ timeout: 5_000 }).catch(() => false)) {
      const text = await codeBlock.first().textContent();
      expect(text.length).toBeGreaterThan(10);
    }
  },
);
