#!/usr/bin/env node
/**
 * Compares browser screenshots against Figma references using pixelmatch.
 * Outputs a diff report and saves diff images.
 *
 * Usage: node scripts/diff-screenshots.mjs [--threshold 0.1]
 */
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from "fs";
import { PNG } from "pngjs";
import pixelmatch from "pixelmatch";

const BROWSER_DIR = new URL("../../../app/src/test-cases/browser-screenshots/", import.meta.url).pathname;
const FIGMA_DIR = new URL("../../../app/src/test-cases/figma-references/", import.meta.url).pathname;
const DIFF_DIR = new URL("../../../app/src/test-cases/diff-output/", import.meta.url).pathname;

const threshold = parseFloat(process.argv.find((a) => a.startsWith("--threshold="))?.split("=")[1] || "0.1");

mkdirSync(DIFF_DIR, { recursive: true });

function loadPng(path) {
  const data = readFileSync(path);
  return PNG.sync.read(data);
}

function resizeToMatch(img, targetWidth, targetHeight) {
  const out = new PNG({ width: targetWidth, height: targetHeight });
  // Copy pixels that fit, pad rest with white
  for (let y = 0; y < targetHeight; y++) {
    for (let x = 0; x < targetWidth; x++) {
      const idx = (y * targetWidth + x) << 2;
      if (x < img.width && y < img.height) {
        const srcIdx = (y * img.width + x) << 2;
        out.data[idx] = img.data[srcIdx];
        out.data[idx + 1] = img.data[srcIdx + 1];
        out.data[idx + 2] = img.data[srcIdx + 2];
        out.data[idx + 3] = img.data[srcIdx + 3];
      } else {
        out.data[idx] = 255;
        out.data[idx + 1] = 255;
        out.data[idx + 2] = 255;
        out.data[idx + 3] = 255;
      }
    }
  }
  return out;
}

function main() {
  if (!existsSync(BROWSER_DIR)) {
    console.error(`Browser screenshots dir not found: ${BROWSER_DIR}`);
    process.exit(1);
  }
  if (!existsSync(FIGMA_DIR)) {
    console.error(`Figma references dir not found: ${FIGMA_DIR}`);
    process.exit(1);
  }

  const browserFiles = readdirSync(BROWSER_DIR).filter((f) => f.endsWith(".png"));
  const figmaFiles = new Set(readdirSync(FIGMA_DIR).filter((f) => f.endsWith(".png")));

  console.log(`Browser screenshots: ${browserFiles.length}`);
  console.log(`Figma references: ${figmaFiles.size}`);
  console.log(`Threshold: ${threshold}`);
  console.log("─".repeat(70));

  const results = [];

  for (const file of browserFiles) {
    if (!figmaFiles.has(file)) {
      results.push({ file, status: "SKIP", reason: "no Figma reference" });
      continue;
    }

    try {
      const browser = loadPng(`${BROWSER_DIR}/${file}`);
      const figma = loadPng(`${FIGMA_DIR}/${file}`);

      // Resize to common dimensions (use the larger of each)
      const w = Math.max(browser.width, figma.width);
      const h = Math.max(browser.height, figma.height);

      const img1 = browser.width === w && browser.height === h ? browser : resizeToMatch(browser, w, h);
      const img2 = figma.width === w && figma.height === h ? figma : resizeToMatch(figma, w, h);

      const diff = new PNG({ width: w, height: h });
      const numDiffPixels = pixelmatch(img1.data, img2.data, diff.data, w, h, {
        threshold,
        includeAA: false,
      });

      const totalPixels = w * h;
      const diffPct = ((numDiffPixels / totalPixels) * 100).toFixed(2);
      const matchPct = (100 - diffPct).toFixed(2);

      // Save diff image
      writeFileSync(`${DIFF_DIR}/${file}`, PNG.sync.write(diff));

      const status = parseFloat(matchPct) >= 99 ? "PASS" : "FAIL";
      results.push({
        file,
        status,
        matchPct: parseFloat(matchPct),
        diffPct: parseFloat(diffPct),
        diffPixels: numDiffPixels,
        totalPixels,
        browserSize: `${browser.width}x${browser.height}`,
        figmaSize: `${figma.width}x${figma.height}`,
      });
    } catch (e) {
      results.push({ file, status: "ERROR", reason: e.message });
    }
  }

  // Report
  console.log("");
  const passing = results.filter((r) => r.status === "PASS");
  const failing = results.filter((r) => r.status === "FAIL");
  const skipped = results.filter((r) => r.status === "SKIP");
  const errors = results.filter((r) => r.status === "ERROR");

  for (const r of results) {
    if (r.status === "PASS") {
      console.log(`  ✓ ${r.file}  ${r.matchPct}% match  (${r.browserSize} vs ${r.figmaSize})`);
    } else if (r.status === "FAIL") {
      console.log(`  ✗ ${r.file}  ${r.matchPct}% match  (${r.diffPixels} diff pixels, ${r.browserSize} vs ${r.figmaSize})`);
    } else if (r.status === "SKIP") {
      console.log(`  - ${r.file}  ${r.reason}`);
    } else {
      console.log(`  ! ${r.file}  ERROR: ${r.reason}`);
    }
  }

  console.log("\n" + "─".repeat(70));
  console.log(`PASS: ${passing.length}  FAIL: ${failing.length}  SKIP: ${skipped.length}  ERROR: ${errors.length}`);
  console.log(`Diff images saved to: ${DIFF_DIR}`);

  if (failing.length > 0) {
    console.log("\nFailing components (below 99% match):");
    for (const r of failing) {
      console.log(`  ${r.file}: ${r.matchPct}% (${r.diffPixels}/${r.totalPixels} pixels differ)`);
    }
  }
}

main();
