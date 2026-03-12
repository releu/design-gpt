import { renderNode } from "./tree-renderer";

figma.showUI(__html__, { width: 320, height: 340 });

figma.ui.onmessage = async (msg: {
  type: string;
  tree: Record<string, unknown>;
  name: string;
}) => {
  if (msg.type !== "render-tree") return;

  try {
    const rootFrame = figma.createFrame();
    rootFrame.name = msg.name || "Design GPT Import";
    rootFrame.layoutMode = "VERTICAL";
    rootFrame.primaryAxisSizingMode = "AUTO";
    rootFrame.counterAxisSizingMode = "AUTO";
    rootFrame.itemSpacing = 0;
    rootFrame.fills = [
      { type: "SOLID", color: { r: 1, g: 1, b: 1 } },
    ];

    const rendered = await renderNode(msg.tree as any);
    rootFrame.appendChild(rendered);

    // Position at viewport center
    const viewport = figma.viewport.center;
    rootFrame.x = Math.round(viewport.x - rootFrame.width / 2);
    rootFrame.y = Math.round(viewport.y - rootFrame.height / 2);

    figma.currentPage.appendChild(rootFrame);
    figma.viewport.scrollAndZoomIntoView([rootFrame]);

    figma.ui.postMessage({ type: "render-done", name: msg.name });
  } catch (err: any) {
    figma.ui.postMessage({
      type: "render-error",
      error: err.message || String(err),
    });
  }
};
