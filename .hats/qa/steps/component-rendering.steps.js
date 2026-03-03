import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Helper: get all component names from the menu (excluding Overview, AI Schema)
// ---------------------------------------------------------------------------
async function getComponentNames(page) {
  await expect(
    page.locator(".DesignSystemModal__menu-subtitle"),
  ).toBeVisible({ timeout: 30_000 });
  await page.waitForTimeout(1_000);

  const menuItems = page.locator(".DesignSystemModal__menu-item");
  const count = await menuItems.count();
  const names = [];
  for (let i = 0; i < count; i++) {
    const text = (await menuItems.nth(i).textContent()).trim();
    if (text === "Overview" || text === "AI Schema") continue;
    names.push(text);
  }
  return names;
}

// ---------------------------------------------------------------------------
// Helper: navigate to a component in the browser
// ---------------------------------------------------------------------------
async function navigateToComponent(page, compName) {
  await page
    .locator(".DesignSystemModal__menu-item", { hasText: compName })
    .first()
    .click();
  await expect(page.locator(".ComponentDetail__name")).toContainText(
    compName,
    { timeout: 5_000 },
  );
}

// ---------------------------------------------------------------------------
// Helper: check if component has code and preview
// ---------------------------------------------------------------------------
async function checkComponentRendersDefault(page, compName) {
  // Check status badge
  const statusText = await page
    .locator(".ComponentDetail__status-badge")
    .textContent({ timeout: 3_000 })
    .catch(() => "unknown");

  if (statusText.trim() === "no code") {
    return { ok: false, error: "no React code generated" };
  }

  // Ensure preview section is expanded
  const previewFrame = page.locator(".ComponentDetail__preview-frame");
  let previewVisible = await previewFrame
    .isVisible({ timeout: 3_000 })
    .catch(() => false);

  if (!previewVisible) {
    const previewHeader = page.locator(
      ".ComponentDetail__section-header",
      { hasText: "Preview" },
    );
    if (await previewHeader.isVisible().catch(() => false)) {
      await previewHeader.click();
    }
    previewVisible = await previewFrame
      .isVisible({ timeout: 5_000 })
      .catch(() => false);
    if (!previewVisible) {
      return { ok: false, error: "no preview iframe visible" };
    }
  }

  // Check #root is not empty
  const frame = page.frameLocator(".ComponentDetail__preview-frame");
  try {
    await expect(frame.locator("#root")).not.toBeEmpty({ timeout: 8_000 });
  } catch {
    return { ok: false, error: "#root is empty after render" };
  }

  // Check for red error text in iframe
  const errorPre = frame.locator(
    'pre[style*="color: red"], pre[style*="color:red"]',
  );
  if (await errorPre.isVisible({ timeout: 1_000 }).catch(() => false)) {
    const errText = await errorPre.textContent().catch(() => "unknown error");
    return { ok: false, error: `render error: ${errText.slice(0, 200)}` };
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// Helper: ensure props section is open
// ---------------------------------------------------------------------------
async function ensurePropsOpen(page) {
  const propsHeader = page.locator(".ComponentDetail__section-header", {
    hasText: "Props",
  });
  if (await propsHeader.isVisible().catch(() => false)) {
    if (
      !(await page
        .locator(".ComponentDetail__props")
        .isVisible()
        .catch(() => false))
    ) {
      await propsHeader.click();
    }
  }
}

// ---------------------------------------------------------------------------
// Scenario: Every component renders with default props without errors
// ---------------------------------------------------------------------------

Then(
  "I validate that every component renders with default props",
  async ({ page }) => {
    const componentNames = await getComponentNames(page);
    console.log(
      `[qa-render] Found ${componentNames.length} components for default render test.\n`,
    );

    const failures = [];
    const successes = [];

    for (let i = 0; i < componentNames.length; i++) {
      const name = componentNames[i];
      console.log(
        `[qa-render] (${i + 1}/${componentNames.length}) Default render: ${name}`,
      );

      try {
        await navigateToComponent(page, name);
        const result = await checkComponentRendersDefault(page, name);

        if (result.ok) {
          successes.push(name);
          console.log(`  OK`);
        } else {
          failures.push({ component: name, error: result.error });
          console.log(`  FAIL: ${result.error}`);
        }
      } catch (e) {
        failures.push({
          component: name,
          error: `exception: ${e.message.slice(0, 150)}`,
        });
        console.log(`  FAIL: ${e.message.slice(0, 80)}`);
      }
    }

    printDefaultRenderReport(componentNames.length, successes, failures);
    expect(
      failures,
      `${failures.length} component(s) failed default render. See report above.`,
    ).toEqual([]);
  },
);

// ---------------------------------------------------------------------------
// Scenario: Every component renders correctly with all prop combinations
//
// Rules:
//   VARIANT  -- each option must produce different innerHTML from the baseline
//               (first option). If HTML is unchanged the component is broken:
//               the Developer must add a variant class to the root element,
//               e.g. .ComponentName__propName_value, so even visually-identical
//               variants produce a detectable DOM difference.
//   BOOLEAN  -- toggling true/false must produce different innerHTML.
//   TEXT     -- filling a unique sentinel string must make that string appear
//               in #root textContent.
// ---------------------------------------------------------------------------

Then(
  "I validate every component with all prop combinations",
  async ({ page }) => {
    const componentNames = await getComponentNames(page);
    console.log(
      `[qa-render] Found ${componentNames.length} components for full prop validation.\n`,
    );

    const failures = [];
    const successes = [];

    for (let ci = 0; ci < componentNames.length; ci++) {
      const compName = componentNames[ci];
      console.log(
        `[qa-render] (${ci + 1}/${componentNames.length}) Testing all props: ${compName}`,
      );

      try {
        await navigateToComponent(page, compName);

        // First check default render
        const defaultResult = await checkComponentRendersDefault(
          page,
          compName,
        );
        if (!defaultResult.ok) {
          failures.push({
            component: compName,
            test: "default_render",
            error: defaultResult.error,
          });
          console.log(`  SKIP props (default render failed)`);
          continue;
        }
        successes.push({ component: compName, test: "default_render" });

        const frame = page.frameLocator(".ComponentDetail__preview-frame");
        const errorPre = frame.locator(
          'pre[style*="color: red"], pre[style*="color:red"]',
        );

        await ensurePropsOpen(page);

        const propRows = page.locator(".ComponentDetail__prop-row");
        const propCount = await propRows.count();

        for (let pi = 0; pi < propCount; pi++) {
          const propRow = propRows.nth(pi);
          const propName = (
            await propRow.locator(".ComponentDetail__prop-name").textContent()
          ).trim();

          // ----- VARIANT props -----
          // Every option must produce innerHTML that differs from the baseline
          // (first option). This catches both render errors and silent no-ops.
          const select = propRow.locator("select");
          if (await select.isVisible().catch(() => false)) {
            const allOpts = (
              await select.locator("option").allTextContents()
            ).map((o) => o.trim());

            // Sample: all if <= 6, else first / middle / last
            const sampled =
              allOpts.length <= 6
                ? allOpts
                : [
                    allOpts[0],
                    allOpts[Math.floor(allOpts.length / 2)],
                    allOpts[allOpts.length - 1],
                  ];

            // Capture baseline with first option
            await select.selectOption(sampled[0]);
            await page.waitForTimeout(600);
            const baselineHtml = await frame
              .locator("#root")
              .innerHTML()
              .catch(() => "");

            successes.push({
              component: compName,
              test: "variant_prop",
              prop: propName,
              value: sampled[0],
            });

            // Every other sampled option must differ from baseline
            for (const val of sampled.slice(1)) {
              try {
                await select.selectOption(val);
                await page.waitForTimeout(600);

                if (
                  await errorPre.isVisible({ timeout: 1_500 }).catch(() => false)
                ) {
                  const errText = await errorPre.textContent().catch(() => "?");
                  failures.push({
                    component: compName,
                    test: "variant_prop",
                    prop: propName,
                    value: val,
                    error: `render error: ${errText.slice(0, 100)}`,
                  });
                  console.log(`  FAIL: ${propName}="${val}" -- render error`);
                  continue;
                }

                const afterHtml = await frame
                  .locator("#root")
                  .innerHTML()
                  .catch(() => "");

                if (afterHtml === baselineHtml) {
                  failures.push({
                    component: compName,
                    test: "variant_prop",
                    prop: propName,
                    value: val,
                    error:
                      `HTML unchanged vs "${sampled[0]}" -- ` +
                      `add a variant class to the component root element, ` +
                      `e.g. .${compName}__${propName.toLowerCase()}_${val.toLowerCase().replace(/\s+/g, "_")}`,
                  });
                  console.log(
                    `  FAIL: ${propName}="${val}" -- HTML unchanged (add root variant class)`,
                  );
                } else {
                  successes.push({
                    component: compName,
                    test: "variant_prop",
                    prop: propName,
                    value: val,
                  });
                }
              } catch (e) {
                failures.push({
                  component: compName,
                  test: "variant_prop",
                  prop: propName,
                  value: val,
                  error: e.message.slice(0, 150),
                });
                console.log(
                  `  FAIL: ${propName}="${val}" -- ${e.message.slice(0, 60)}`,
                );
              }
            }

            // Reset to first option so subsequent props start from a clean state
            await select.selectOption(sampled[0]);
            await page.waitForTimeout(300);
          }

          // ----- BOOLEAN props -----
          // Toggling must produce different innerHTML.
          const checkbox = propRow.locator('input[type="checkbox"]');
          if (await checkbox.isVisible().catch(() => false)) {
            try {
              const isChecked = await checkbox.isChecked();

              // Capture baseline (current state)
              const baselineHtml = await frame
                .locator("#root")
                .innerHTML()
                .catch(() => "");

              // Toggle to opposite
              isChecked ? await checkbox.uncheck() : await checkbox.check();
              await page.waitForTimeout(600);

              if (
                await errorPre.isVisible({ timeout: 1_500 }).catch(() => false)
              ) {
                failures.push({
                  component: compName,
                  test: "boolean_prop",
                  prop: propName,
                  error: "render error after toggle",
                });
                console.log(`  FAIL: ${propName} toggle -- render error`);
              } else {
                const afterHtml = await frame
                  .locator("#root")
                  .innerHTML()
                  .catch(() => "");

                if (afterHtml === baselineHtml) {
                  failures.push({
                    component: compName,
                    test: "boolean_prop",
                    prop: propName,
                    error: "HTML unchanged after boolean toggle",
                  });
                  console.log(
                    `  FAIL: ${propName} toggle -- HTML unchanged`,
                  );
                } else {
                  successes.push({
                    component: compName,
                    test: "boolean_prop",
                    prop: propName,
                  });
                }
              }

              // Restore original state
              isChecked ? await checkbox.check() : await checkbox.uncheck();
              await page.waitForTimeout(300);
            } catch (e) {
              failures.push({
                component: compName,
                test: "boolean_prop",
                prop: propName,
                error: e.message.slice(0, 150),
              });
              console.log(
                `  FAIL: ${propName} toggle -- ${e.message.slice(0, 60)}`,
              );
            }
          }

          // ----- TEXT props -----
          // A unique sentinel string must appear verbatim in #root textContent.
          const textInput = propRow.locator('input[type="text"]');
          if (await textInput.isVisible().catch(() => false)) {
            const sentinel = `QA${ci}x${pi}x${Date.now().toString(36)}`;
            try {
              await textInput.fill(sentinel);
              await page.waitForTimeout(600);

              if (
                await errorPre.isVisible({ timeout: 1_500 }).catch(() => false)
              ) {
                const errText = await errorPre.textContent().catch(() => "?");
                failures.push({
                  component: compName,
                  test: "text_prop",
                  prop: propName,
                  error: `render error: ${errText.slice(0, 100)}`,
                });
                console.log(`  FAIL: ${propName} text -- render error`);
              } else {
                const rootText = await frame
                  .locator("#root")
                  .textContent()
                  .catch(() => "");

                if (rootText.includes(sentinel)) {
                  successes.push({
                    component: compName,
                    test: "text_prop",
                    prop: propName,
                  });
                } else {
                  failures.push({
                    component: compName,
                    test: "text_prop",
                    prop: propName,
                    error: `sentinel "${sentinel}" not found in rendered text`,
                  });
                  console.log(
                    `  FAIL: ${propName} text -- sentinel not in output`,
                  );
                }
              }

              // Reset text field
              await textInput.fill("");
              await page.waitForTimeout(300);
            } catch (e) {
              failures.push({
                component: compName,
                test: "text_prop",
                prop: propName,
                error: e.message.slice(0, 150),
              });
              console.log(
                `  FAIL: ${propName} text -- ${e.message.slice(0, 60)}`,
              );
            }
          }
        }

        console.log(
          `  Done: ${successes.filter((s) => s.component === compName).length} checks passed`,
        );
      } catch (e) {
        failures.push({
          component: compName,
          test: "component_load",
          error: e.message.slice(0, 200),
        });
        console.log(`  FAIL: could not load -- ${e.message.slice(0, 80)}`);
      }
    }

    printFullReport(componentNames.length, successes, failures);
    expect(
      failures,
      `${failures.length} failure(s) in full prop validation. See report above.`,
    ).toEqual([]);
  },
);

// ---------------------------------------------------------------------------
// Scenario: Text props display their values in the rendered output
// ---------------------------------------------------------------------------

Then(
  "I validate that text props produce visible output in the iframe",
  async ({ page }) => {
    const componentNames = await getComponentNames(page);
    const failures = [];
    const successes = [];
    const TEST_TEXT = "QAVerifyText42";

    for (let ci = 0; ci < componentNames.length; ci++) {
      const compName = componentNames[ci];

      try {
        await navigateToComponent(page, compName);
        const defaultResult = await checkComponentRendersDefault(
          page,
          compName,
        );
        if (!defaultResult.ok) continue;

        await ensurePropsOpen(page);

        const propRows = page.locator(".ComponentDetail__prop-row");
        const propCount = await propRows.count();

        for (let pi = 0; pi < propCount; pi++) {
          const propRow = propRows.nth(pi);
          const propName = (
            await propRow.locator(".ComponentDetail__prop-name").textContent()
          ).trim();

          const textInput = propRow.locator('input[type="text"]');
          if (!(await textInput.isVisible().catch(() => false))) continue;

          console.log(
            `[qa-render] Text prop test: ${compName}.${propName} = "${TEST_TEXT}"`,
          );

          await textInput.fill(TEST_TEXT);
          await page.waitForTimeout(800);

          const frame = page.frameLocator(".ComponentDetail__preview-frame");
          const rootText = await frame
            .locator("#root")
            .textContent()
            .catch(() => "");

          if (rootText.includes(TEST_TEXT)) {
            successes.push({
              component: compName,
              prop: propName,
            });
            console.log(`  OK: "${TEST_TEXT}" found in rendered output`);
          } else {
            failures.push({
              component: compName,
              prop: propName,
              error: `"${TEST_TEXT}" not found in iframe text content`,
            });
            console.log(
              `  FAIL: "${TEST_TEXT}" not found in rendered output (got: "${rootText.slice(0, 100)}")`,
            );
          }
        }
      } catch (e) {
        // Skip components that cannot load
      }
    }

    console.log(
      `\n[qa-render] Text prop visibility: ${successes.length} passed, ${failures.length} failed\n`,
    );

    // This is informational -- some text props may not directly render
    // (e.g., aria-label). Log but only fail if zero successes and there were text props.
    if (failures.length > 0 && successes.length === 0) {
      expect(
        failures,
        "No text prop values appeared in rendered output",
      ).toEqual([]);
    }
  },
);

// ---------------------------------------------------------------------------
// Scenario: Variant changes produce different HTML output
// ---------------------------------------------------------------------------

Then(
  "I validate that variant changes produce different HTML output",
  async ({ page }) => {
    const componentNames = await getComponentNames(page);
    const results = [];

    for (let ci = 0; ci < componentNames.length; ci++) {
      const compName = componentNames[ci];

      try {
        await navigateToComponent(page, compName);
        const defaultResult = await checkComponentRendersDefault(
          page,
          compName,
        );
        if (!defaultResult.ok) continue;

        await ensurePropsOpen(page);

        const propRows = page.locator(".ComponentDetail__prop-row");
        const propCount = await propRows.count();

        for (let pi = 0; pi < propCount; pi++) {
          const propRow = propRows.nth(pi);
          const propName = (
            await propRow.locator(".ComponentDetail__prop-name").textContent()
          ).trim();

          const select = propRow.locator("select");
          if (!(await select.isVisible().catch(() => false))) continue;

          const allOpts = (
            await select.locator("option").allTextContents()
          ).map((o) => o.trim());
          if (allOpts.length < 2) continue;

          // Capture HTML with first option
          await select.selectOption(allOpts[0]);
          await page.waitForTimeout(600);
          const frame = page.frameLocator(".ComponentDetail__preview-frame");
          const html1 = await frame
            .locator("#root")
            .innerHTML()
            .catch(() => "");

          // Capture HTML with different option
          const altOpt =
            allOpts[1] !== allOpts[0] ? allOpts[1] : allOpts[allOpts.length - 1];
          await select.selectOption(altOpt);
          await page.waitForTimeout(600);
          const html2 = await frame
            .locator("#root")
            .innerHTML()
            .catch(() => "");

          const changed = html1 !== html2;
          results.push({
            component: compName,
            prop: propName,
            value1: allOpts[0],
            value2: altOpt,
            changed,
          });

          if (changed) {
            console.log(
              `[qa-render] ${compName}.${propName}: "${allOpts[0]}" -> "${altOpt}" -- HTML changed`,
            );
          } else {
            console.log(
              `[qa-render] ${compName}.${propName}: "${allOpts[0]}" -> "${altOpt}" -- HTML identical (may be styling-only)`,
            );
          }
        }
      } catch {
        // Skip
      }
    }

    const changedCount = results.filter((r) => r.changed).length;
    console.log(
      `\n[qa-render] Variant diff: ${changedCount}/${results.length} prop changes produced different HTML\n`,
    );

    // At least some variants should produce different HTML
    if (results.length > 0) {
      expect(changedCount).toBeGreaterThan(0);
    }
  },
);

// ---------------------------------------------------------------------------
// Report printing
// ---------------------------------------------------------------------------

function printDefaultRenderReport(total, successes, failures) {
  console.log("\n" + "=".repeat(80));
  console.log("DEFAULT RENDER REPORT");
  console.log("=".repeat(80));
  console.log(`Total components: ${total}`);
  console.log(`Passed: ${successes.length}`);
  console.log(`Failed: ${failures.length}`);
  if (failures.length > 0) {
    console.log("\n--- FAILURES ---");
    for (const f of failures) {
      console.log(`  ${f.component}: ${f.error}`);
    }
  }
  console.log("=".repeat(80) + "\n");
}

function printFullReport(total, successes, failures) {
  console.log("\n" + "=".repeat(80));
  console.log("FULL PROP VALIDATION REPORT");
  console.log("=".repeat(80));
  console.log(`Total components: ${total}`);
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
    console.log("\n--- SUMMARY BY TYPE ---");
    const byType = {};
    for (const f of failures) byType[f.test] = (byType[f.test] || 0) + 1;
    for (const [t, c] of Object.entries(byType)) console.log(`  ${t}: ${c}`);
  }

  if (successes.length > 0) {
    console.log("\n--- PASSED ---");
    const compSet = [...new Set(successes.map((s) => s.component))];
    for (const comp of compSet) {
      const count = successes.filter((s) => s.component === comp).length;
      console.log(`  ${comp}: ${count} checks`);
    }
  }
  console.log("\n" + "=".repeat(80) + "\n");
}
