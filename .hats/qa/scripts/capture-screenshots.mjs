#!/usr/bin/env node
/**
 * Captures browser screenshots of all test-case pages using Playwright.
 * Requires: npx playwright install chromium
 *
 * Usage: node scripts/capture-screenshots.mjs [--base-url http://localhost:5173]
 */
import { chromium } from "@playwright/test";
import { mkdirSync } from "fs";
import { components, frames } from "../../../app/src/test-cases/config.js";

const BASE_URL = process.argv.find(a => a.startsWith("--base-url="))?.split("=")[1] || "http://localhost:5173";
const OUT_DIR = new URL("../../../app/src/test-cases/browser-screenshots/", import.meta.url).pathname;

mkdirSync(OUT_DIR, { recursive: true });

async function main() {
  const browser = await chromium.launch();
  const context = await browser.newContext({ deviceScaleFactor: 2 });

  console.log("Capturing browser screenshots...\n");

  // Components
  for (const [name, cfg] of Object.entries(components)) {
    if (cfg.variants) {
      for (const v of cfg.variants) {
        const outName = `${name}--${v.name}`;
        await capture(context, `${BASE_URL}/test-cases/components/${name}?variant=${v.name}`, outName, cfg.width, cfg.height);
      }
    } else {
      await capture(context, `${BASE_URL}/test-cases/components/${name}`, name, cfg.width, cfg.height);
    }
  }

  // Frames
  for (const [name, cfg] of Object.entries(frames)) {
    await capture(context, `${BASE_URL}/test-cases/frames/${name}`, `frame--${name}`, cfg.width, cfg.height);
  }

  await browser.close();
  console.log("\nDone.");
}

async function capture(context, url, outName, width, height) {
  const page = await context.newPage({ viewport: { width, height } });
  try {
    await page.goto(url, { waitUntil: "networkidle", timeout: 15000 });
    // Wait for any rendering to settle
    await page.waitForTimeout(500);

    const testCase = page.locator('[qa="test-case"]');
    if (await testCase.isVisible({ timeout: 3000 }).catch(() => false)) {
      await testCase.screenshot({ path: `${OUT_DIR}/${outName}.png` });
      console.log(`  OK ${outName}`);
    } else {
      // Fallback: screenshot the full page
      await page.screenshot({ path: `${OUT_DIR}/${outName}.png` });
      console.log(`  OK ${outName} (full page)`);
    }
  } catch (e) {
    console.error(`  FAIL ${outName}: ${e.message.slice(0, 100)}`);
  } finally {
    await page.close();
  }
}

main().catch(e => { console.error(e); process.exit(1); });
