// Hot-reloadable rendering logic.
// This file is bundled as IIFE → served by figma-dev-loop → eval'd in the Figma plugin sandbox.
// It overwrites the global handler so fresh code runs without reloading the plugin.

import { renderNode, pendingImageFills } from "./tree-renderer";

const PLUGIN_VERSION = "v12";
const MAX_DEV_LOGS = 200;

// Save original console methods on first eval only (prevents stacking wrappers)
if (!(globalThis as any).__origConsoleLog) {
  (globalThis as any).__origConsoleLog = console.log;
  (globalThis as any).__origConsoleWarn = console.warn;
}
const _origLog = (globalThis as any).__origConsoleLog;
const _origWarn = (globalThis as any).__origConsoleWarn;

// Capture logs for dev result reporting (capped)
(globalThis as any).__devLogs = [];
console.log = (...args: any[]) => {
  const logs = (globalThis as any).__devLogs;
  if (logs.length < MAX_DEV_LOGS) logs.push(args.join(" "));
  _origLog.apply(console, args);
};
console.warn = (...args: any[]) => {
  const logs = (globalThis as any).__devLogs;
  if (logs.length < MAX_DEV_LOGS) logs.push("[WARN] " + args.join(" "));
  _origWarn.apply(console, args);
};

// Save previous handler for rollback on failure
const _previousHandler = (globalThis as any).__handlePluginMessage;

try {
  (globalThis as any).__handlePluginMessage = async (msg: any) => {
    if (msg.type === "render-tree") {
      try {
        (globalThis as any).__devLogs = [];
        pendingImageFills.length = 0;

        // Clean up previous dev frames
        const prevFrames = figma.currentPage.children.filter(
          (n) => n.type === "FRAME" && n.name.startsWith("[v")
        );
        for (const f of prevFrames) {
          try { f.remove(); } catch (_) {}
        }

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
    } else if (msg.type === "dev-inspect") {
      try {
        const value = eval(msg.expression);
        const serialized = typeof value === "object" ? JSON.stringify(value, null, 2) : String(value);
        figma.ui.postMessage({ type: "dev-inspect-done", value: serialized });
      } catch (e: any) {
        figma.ui.postMessage({ type: "dev-inspect-error", error: e.message || String(e) });
      }
    }
  };
} catch (e) {
  // Restore previous handler if setup fails
  (globalThis as any).__handlePluginMessage = _previousHandler;
  throw e;
}
