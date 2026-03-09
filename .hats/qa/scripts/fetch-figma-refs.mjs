#!/usr/bin/env node
/**
 * Fetches Figma screenshots for all components/variants/frames in test-cases/config.js
 * and saves them to test-cases/figma-references/.
 *
 * Usage: FIGMA_TOKEN=xxx node scripts/fetch-figma-refs.mjs
 */
import { writeFileSync, mkdirSync } from "fs";
import { components, frames } from "../../../app/src/test-cases/config.js";

const TOKEN = process.env.FIGMA_TOKEN;
if (!TOKEN) {
  console.error("FIGMA_TOKEN env var required");
  process.exit(1);
}

const FILE_KEY = "9UzId8cZXBggKGCxV7JJdY";
const OUT_DIR = new URL("../../../app/src/test-cases/figma-references/", import.meta.url).pathname;

mkdirSync(OUT_DIR, { recursive: true });

async function fetchImage(nodeId, outName) {
  const encoded = nodeId.replace(":", "-");
  const url = `https://api.figma.com/v1/images/${FILE_KEY}?ids=${encoded}&format=png&scale=2`;
  const res = await fetch(url, {
    headers: { "X-Figma-Token": TOKEN },
  });
  if (!res.ok) {
    console.error(`  FAIL ${outName}: ${res.status} ${res.statusText}`);
    return false;
  }
  const json = await res.json();
  const imageUrl = json.images?.[nodeId];
  if (!imageUrl) {
    console.error(`  FAIL ${outName}: no image URL returned for ${nodeId}`);
    return false;
  }

  const imgRes = await fetch(imageUrl);
  if (!imgRes.ok) {
    console.error(`  FAIL ${outName}: image download failed ${imgRes.status}`);
    return false;
  }
  const buf = Buffer.from(await imgRes.arrayBuffer());
  writeFileSync(`${OUT_DIR}/${outName}.png`, buf);
  console.log(`  OK ${outName} (${buf.length} bytes)`);
  return true;
}

async function main() {
  console.log("Fetching Figma reference screenshots...\n");

  // Components
  for (const [name, cfg] of Object.entries(components)) {
    if (cfg.variants) {
      for (const v of cfg.variants) {
        await fetchImage(v.figmaId, `${name}--${v.name}`);
      }
    } else {
      await fetchImage(cfg.figmaId, name);
    }
  }

  // Frames
  for (const [name, cfg] of Object.entries(frames)) {
    await fetchImage(cfg.figmaId, `frame--${name}`);
  }

  console.log("\nDone.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
