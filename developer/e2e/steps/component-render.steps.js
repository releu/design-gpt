import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { When, Then } = createBdd(test);

const FIGMA_URL =
  "https://www.figma.com/design/WtrKhqs65LdhvIjOqnwVmV/%F0%9F%92%8E-DC-%E2%80%A2-Cubes";

// ---------------------------------------------------------------------------
// Scenario 1: Import via UI (same proven pattern as existing E2E tests)
// ---------------------------------------------------------------------------

When(
  "I ensure the Cubes library is imported as {string}",
  async ({ page }, dsName) => {
    // Check if design system already exists
    const dsLocator = page.locator(".LibrarySelector__item-name", { hasText: dsName });
    const alreadyExists = await dsLocator.first().isVisible({ timeout: 10_000 }).catch(() => false);

    if (alreadyExists) {
      console.log(`[render-test] Design system "${dsName}" found in UI, skipping import.`);
      return;
    }

    console.log(`[render-test] Importing via UI...`);

    // Open design system modal
    await page.click(".LibrarySelector__new-ds");
    await expect(page.locator(".DesignSystemModal")).toBeVisible();

    // Add Figma URL
    page.once("dialog", async (dialog) => await dialog.accept(FIGMA_URL));
    await page.click(".DesignSystemModal__source-btn >> text=+ Figma");
    await expect(page.locator(".DesignSystemModal__url-text")).toBeVisible();
    console.log(`[render-test] Figma URL added, starting import...`);

    // Click Import
    await page.click(".DesignSystemModal__do-import");

    // Poll the UI for progress
    const startTime = Date.now();
    let lastStatus = "";

    while (true) {
      const browserVisible = await page
        .locator(".DesignSystemModal__browser")
        .isVisible()
        .catch(() => false);

      if (browserVisible) {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(`[render-test] [${elapsed}s] Component browser visible — import complete!`);
        break;
      }

      // Read current status from the modal
      const statusText = await page.locator(".DesignSystemModal__box").first().textContent().catch(() => "");
      const shortStatus = statusText.replace(/\s+/g, " ").trim().slice(0, 120);
      if (shortStatus !== lastStatus) {
        const elapsed = Math.round((Date.now() - startTime) / 1000);
        console.log(`[render-test] [${elapsed}s] ${shortStatus}`);
        lastStatus = shortStatus;
      }

      await page.waitForTimeout(5_000);
    }

    // Name and save
    await page.fill(".DesignSystemModal__overview-name-input", dsName);
    await page.click(".DesignSystemModal__save-btn");
    await expect(page.locator(".DesignSystemModal")).not.toBeVisible({ timeout: 5_000 });
    console.log(`[render-test] Design system "${dsName}" saved.`);
  },
);

// ---------------------------------------------------------------------------
// Scenario 2: Validate every component
// ---------------------------------------------------------------------------

Then(
  "I validate rendering of every component in the browser",
  async ({ page }) => {
    const failures = [];
    const successes = [];

    // Wait for component menu items to load
    await expect(page.locator(".DesignSystemModal__menu-subtitle")).toBeVisible({
      timeout: 30_000,
    });
    await page.waitForTimeout(1_000);

    const menuItems = page.locator(".DesignSystemModal__menu-item");
    const count = await menuItems.count();
    console.log(`[render-test] Menu items found: ${count}`);

    const componentNames = [];
    for (let i = 0; i < count; i++) {
      const text = await menuItems.nth(i).textContent();
      const trimmed = text.trim();
      if (trimmed === "Overview" || trimmed === "AI Schema") continue;
      componentNames.push(trimmed);
    }

    console.log(`[render-test] Found ${componentNames.length} components to validate.\n`);

    let consecutiveSameFailure = 0;
    let lastFailureType = "";

    for (let ci = 0; ci < componentNames.length; ci++) {
      const compName = componentNames[ci];
      console.log(`[render-test] (${ci + 1}/${componentNames.length}) Testing: ${compName}`);

      try {
        await page
          .locator(".DesignSystemModal__menu-item", { hasText: compName })
          .first()
          .click();

        await expect(
          page.locator(".ComponentDetail__name"),
        ).toContainText(compName, { timeout: 5_000 });

        // Check 1: react code exists
        const statusText = await page
          .locator(".ComponentDetail__status-badge")
          .textContent({ timeout: 3_000 })
          .catch(() => "unknown");

        if (statusText.trim() === "no code") {
          failures.push({ component: compName, test: "has_react_code", error: "no code badge" });
          console.log(`  FAIL: no React code`);
          continue;
        }

        // Check 2: preview iframe visible
        const previewFrame = page.locator(".ComponentDetail__preview-frame");
        let previewVisible = await previewFrame.isVisible({ timeout: 3_000 }).catch(() => false);

        if (!previewVisible) {
          const previewHeader = page.locator(".ComponentDetail__section-header", { hasText: "Preview" });
          if (await previewHeader.isVisible().catch(() => false)) await previewHeader.click();
          previewVisible = await previewFrame.isVisible({ timeout: 5_000 }).catch(() => false);
          if (!previewVisible) {
            failures.push({ component: compName, test: "preview_visible", error: "no preview iframe" });
            console.log(`  FAIL: no preview iframe`);
            continue;
          }
        }

        // Check 3: non-empty render
        const frame = page.frameLocator(".ComponentDetail__preview-frame");
        try {
          await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 5_000 });
        } catch {
          failures.push({ component: compName, test: "default_render_not_empty", error: "#root empty" });
          console.log(`  FAIL: #root empty`);
          continue;
        }

        // Check 4: no render error
        const errorPre = frame.locator('pre[style*="color: red"], pre[style*="color:red"]');
        if (await errorPre.isVisible({ timeout: 1_000 }).catch(() => false)) {
          const errText = await errorPre.textContent().catch(() => "?");
          failures.push({ component: compName, test: "default_render_no_error", error: errText.slice(0, 200) });
          console.log(`  FAIL: render error — ${errText.slice(0, 80)}`);
          continue;
        }

        successes.push({ component: compName, test: "default_render" });
        console.log(`  OK: default render`);

        // Check 5: test each prop
        const propsHeader = page.locator(".ComponentDetail__section-header", { hasText: "Props" });
        if (await propsHeader.isVisible().catch(() => false)) {
          if (!(await page.locator(".ComponentDetail__props").isVisible().catch(() => false))) {
            await propsHeader.click();
          }
        }

        const propRows = page.locator(".ComponentDetail__prop-row");
        const propCount = await propRows.count();

        for (let pi = 0; pi < propCount; pi++) {
          const propRow = propRows.nth(pi);
          const propName = (await propRow.locator(".ComponentDetail__prop-name").textContent()).trim();

          // VARIANT
          const select = propRow.locator("select");
          if (await select.isVisible().catch(() => false)) {
            const allOpts = (await select.locator("option").allTextContents()).map((o) => o.trim());
            // Sample: first, middle, last (avoid testing 200+ country flags)
            const sampled =
              allOpts.length <= 5
                ? allOpts
                : [allOpts[0], allOpts[Math.floor(allOpts.length / 2)], allOpts[allOpts.length - 1]];
            for (const val of sampled) {
              try {
                await select.selectOption(val);
                await page.waitForTimeout(500);
                if (await errorPre.isVisible({ timeout: 1_000 }).catch(() => false)) {
                  failures.push({ component: compName, test: "prop_variant", prop: propName, value: val, error: "render error" });
                  console.log(`  FAIL: ${propName}="${val}" — render error`);
                } else {
                  const c = await frame.locator("#root").innerHTML().catch(() => "");
                  if (!c.trim()) {
                    failures.push({ component: compName, test: "prop_variant", prop: propName, value: val, error: "#root empty" });
                    console.log(`  FAIL: ${propName}="${val}" — empty`);
                  } else {
                    successes.push({ component: compName, test: "prop_variant", prop: propName, value: val });
                  }
                }
              } catch (e) {
                failures.push({ component: compName, test: "prop_variant", prop: propName, value: val, error: e.message.slice(0, 150) });
                console.log(`  FAIL: ${propName}="${val}" — ${e.message.slice(0, 60)}`);
              }
            }
          }

          // BOOLEAN
          const checkbox = propRow.locator('input[type="checkbox"]');
          if (await checkbox.isVisible().catch(() => false)) {
            for (const checked of [true, false]) {
              try {
                checked ? await checkbox.check() : await checkbox.uncheck();
                await page.waitForTimeout(500);
                if (await errorPre.isVisible({ timeout: 1_000 }).catch(() => false)) {
                  failures.push({ component: compName, test: "prop_boolean", prop: propName, value: String(checked), error: "render error" });
                  console.log(`  FAIL: ${propName}=${checked} — render error`);
                } else {
                  successes.push({ component: compName, test: "prop_boolean", prop: propName, value: String(checked) });
                }
              } catch (e) {
                failures.push({ component: compName, test: "prop_boolean", prop: propName, value: String(checked), error: e.message.slice(0, 150) });
                console.log(`  FAIL: ${propName}=${checked} — ${e.message.slice(0, 60)}`);
              }
            }
          }

          // TEXT
          const textInput = propRow.locator('input[type="text"]');
          if (await textInput.isVisible().catch(() => false)) {
            for (const testVal of ["Hello World", ""]) {
              const label = testVal || "(empty)";
              try {
                await textInput.fill(testVal);
                await page.waitForTimeout(500);
                if (await errorPre.isVisible({ timeout: 1_000 }).catch(() => false)) {
                  failures.push({ component: compName, test: "prop_text", prop: propName, value: label, error: "render error" });
                  console.log(`  FAIL: ${propName}="${label}" — render error`);
                } else {
                  successes.push({ component: compName, test: "prop_text", prop: propName, value: label });
                }
              } catch (e) {
                failures.push({ component: compName, test: "prop_text", prop: propName, value: label, error: e.message.slice(0, 150) });
                console.log(`  FAIL: ${propName}="${label}" — ${e.message.slice(0, 60)}`);
              }
            }
          }
        }
      } catch (e) {
        failures.push({ component: compName, test: "component_load", error: e.message.slice(0, 200) });
        console.log(`  FAIL: could not load — ${e.message.slice(0, 80)}`);
      }
    }

    // Report
    printReport(componentNames, successes, failures);
    expect(failures, `${failures.length} failure(s). See report above.`).toEqual([]);
  },
);

// ---------------------------------------------------------------------------
function printReport(componentNames, successes, failures) {
  console.log("\n" + "=".repeat(80));
  console.log("COMPONENT RENDERING REPORT");
  console.log("=".repeat(80));
  console.log(`Total components: ${componentNames.length}`);
  console.log(`Passed checks: ${successes.length}`);
  console.log(`Failed checks: ${failures.length}`);

  if (failures.length > 0) {
    console.log("\n--- FAILURES ---");
    const byComponent = {};
    for (const f of failures) (byComponent[f.component] ||= []).push(f);
    for (const [comp, fs] of Object.entries(byComponent)) {
      console.log(`\n  ${comp}:`);
      for (const f of fs) {
        const p = f.prop ? ` [${f.prop}=${f.value}]` : "";
        console.log(`    FAIL ${f.test}${p}: ${f.error}`);
      }
    }
    console.log("\n--- SUMMARY ---");
    const byType = {};
    for (const f of failures) byType[f.test] = (byType[f.test] || 0) + 1;
    for (const [t, c] of Object.entries(byType)) console.log(`  ${t}: ${c}`);
  }

  if (successes.length > 0) {
    console.log("\n--- PASSED ---");
    for (const comp of [...new Set(successes.map((s) => s.component))]) {
      console.log(`  ${comp}: ${successes.filter((s) => s.component === comp).length} checks`);
    }
  }
  console.log("\n" + "=".repeat(80) + "\n");
}
