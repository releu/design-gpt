import { renderNode, pendingImageFills } from "./tree-renderer";

const PLUGIN_VERSION = "v7";

figma.showUI(__html__, { width: 320, height: 340 });

// Default handler — can be overwritten by dev-eval with fresh code
(globalThis as any).__handlePluginMessage = async (msg: any) => {
  if (msg.type === "render-tree") {
    try {
      pendingImageFills.length = 0;

      // Clean up previous dev frames before rendering a new one
      if (msg.dev) {
        const prevFrames = figma.currentPage.children.filter(
          (n) => n.type === "FRAME" && n.name.startsWith("[v")
        );
        for (const f of prevFrames) {
          try { f.remove(); } catch (_) {}
        }
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
    // Evaluate an expression and return the result (for reading Figma state)
    try {
      const value = eval(msg.expression);
      const serialized = typeof value === "object" ? JSON.stringify(value, null, 2) : String(value);
      figma.ui.postMessage({ type: "dev-inspect-done", value: serialized });
    } catch (e: any) {
      figma.ui.postMessage({ type: "dev-inspect-error", error: e.message || String(e) });
    }
  }
};

// Stable dispatcher — never changes, supports dev-eval hot-reload
// Top-level catch-all: the plugin must never die from an unhandled error
figma.ui.onmessage = async (msg: any) => {
  try {
    if (msg.type === "dev-eval") {
      try {
        eval(msg.code);
        figma.ui.postMessage({ type: "dev-eval-done" });
      } catch (e: any) {
        figma.ui.postMessage({ type: "dev-eval-error", error: e.message || String(e) });
      }
      return;
    }
    await (globalThis as any).__handlePluginMessage(msg);
  } catch (e: any) {
    // Last resort — report but never crash
    figma.ui.postMessage({ type: "fatal-error", error: e.message || String(e) });
  }
};
