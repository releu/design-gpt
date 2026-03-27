// MCP entry point — top-level await, bundled as ESM for use_figma sandbox.

import { renderNode, pendingImageFills, collectImageSwapFills } from "./tree-renderer";

declare const __TREE__: any;
declare const __NAME__: string;

const tree = __TREE__;
const name = __NAME__ || "Design GPT Import";

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

const viewport = figma.viewport.center;
rootFrame.x = Math.round(viewport.x - rootFrame.width / 2);
rootFrame.y = Math.round(viewport.y - rootFrame.height / 2);

figma.currentPage.appendChild(rootFrame);
figma.viewport.scrollAndZoomIntoView([rootFrame]);

collectImageSwapFills(rootFrame);

figma.notify(`✓ Rendered "${name}" (${Math.round(rootFrame.width)}×${Math.round(rootFrame.height)})`);
