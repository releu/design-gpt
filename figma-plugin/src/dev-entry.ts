// Hot-reloadable rendering logic.
// This file is bundled as IIFE → served by Rails → eval'd in the Figma plugin sandbox.
// It overwrites the global handler so fresh code runs without reloading the plugin.

import { renderNode, pendingImageFills } from "./tree-renderer";

const PLUGIN_VERSION = "v11";

// Capture logs for dev result reporting
(globalThis as any).__devLogs = [];
const _origLog = console.log;
const _origWarn = console.warn;
console.log = (...args: any[]) => { (globalThis as any).__devLogs.push(args.join(" ")); _origLog.apply(console, args); };
console.warn = (...args: any[]) => { (globalThis as any).__devLogs.push("[WARN] " + args.join(" ")); _origWarn.apply(console, args); };

(globalThis as any).__handlePluginMessage = async (msg: any) => {
  if (msg.type === "render-tree") {
    try {
      (globalThis as any).__devLogs = [];
      pendingImageFills.length = 0;

      const baseName = msg.name || "Design GPT Import";
      const rootFrame = figma.createFrame();
      rootFrame.name = msg.dev
        ? `[${PLUGIN_VERSION}] ${baseName}`
        : baseName;
      rootFrame.layoutMode = "VERTICAL";
      rootFrame.primaryAxisSizingMode = "AUTO";
      rootFrame.counterAxisSizingMode = "AUTO";
      rootFrame.itemSpacing = 0;
      rootFrame.fills = [
        { type: "SOLID", color: { r: 1, g: 1, b: 1 } },
      ];

      const rendered = await renderNode(msg.tree as any);
      rootFrame.appendChild(rendered);

      const viewport = figma.viewport.center;
      rootFrame.x = Math.round(viewport.x - rootFrame.width / 2);
      rootFrame.y = Math.round(viewport.y - rootFrame.height / 2);

      figma.currentPage.appendChild(rootFrame);
      figma.viewport.scrollAndZoomIntoView([rootFrame]);

      if (pendingImageFills.length > 0) {
        figma.ui.postMessage({ type: "fetch-images", fills: [...pendingImageFills] });
      }

      figma.ui.postMessage({ type: "render-done", name: msg.name, logs: (globalThis as any).__devLogs || [] });
    } catch (err: any) {
      figma.ui.postMessage({
        type: "render-error",
        error: err.message || String(err),
        logs: (globalThis as any).__devLogs || [],
      });
    }
  } else if (msg.type === "image-data") {
    try {
      const node = figma.getNodeById(msg.nodeId);
      if (node && ("fills" in node)) {
        const image = figma.createImage(new Uint8Array(msg.bytes));
        (node as GeometryMixin & SceneNode).fills = [
          { type: "IMAGE", imageHash: image.hash, scaleMode: "FILL" },
        ];
      }
    } catch (err) {
      console.warn("Failed to apply image fill to " + msg.nodeId, err);
    }
  }
};
