// MCP entry point — top-level await, bundled as ESM for use_figma sandbox.

import { renderNode, pendingImageFills, collectImageSwapFills } from "./tree-renderer";

declare const __TREE__: any;
declare const __NAME__: string;

const tree = __TREE__;
const name = __NAME__ || "Design GPT Import";

// Remove previous frame with the same name on current page
for (const child of [...figma.currentPage.children]) {
  if (child.name === name) {
    try { child.remove(); } catch (_) {}
  }
}

const rootFrame = figma.createFrame();
rootFrame.name = name;
rootFrame.layoutMode = "VERTICAL";
rootFrame.primaryAxisSizingMode = "AUTO";
rootFrame.counterAxisSizingMode = "AUTO";
rootFrame.itemSpacing = 0;
rootFrame.fills = [
  { type: "SOLID", color: { r: 1, g: 1, b: 1 } },
];

const rendered = await renderNode(tree);
rootFrame.appendChild(rendered);

rootFrame.x = 0;
rootFrame.y = 0;
figma.currentPage.appendChild(rootFrame);

collectImageSwapFills(rootFrame);

figma.notify(`✓ Rendered "${name}" (${Math.round(rootFrame.width)}×${Math.round(rootFrame.height)})`);
