import { renderNode, pendingImageFills } from "./tree-renderer";

figma.showUI(__html__, { width: 320, height: 340 });

figma.ui.onmessage = async (msg: any) => {
  if (msg.type === "render-tree") {
    try {
      // Clear pending fills from any previous render
      pendingImageFills.length = 0;

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

      // Send pending image fills to UI for fetching
      if (pendingImageFills.length > 0) {
        figma.ui.postMessage({ type: "fetch-images", fills: [...pendingImageFills] });
      }

      figma.ui.postMessage({ type: "render-done", name: msg.name });
    } catch (err: any) {
      figma.ui.postMessage({
        type: "render-error",
        error: err.message || String(err),
      });
    }
  } else if (msg.type === "image-data") {
    // Apply fetched image bytes as fill to the target node
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
