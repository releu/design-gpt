"use strict";
(() => {
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __esm = (fn, res) => function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __async = (__this, __arguments, generator) => {
    return new Promise((resolve, reject) => {
      var fulfilled = (value) => {
        try {
          step(generator.next(value));
        } catch (e) {
          reject(e);
        }
      };
      var rejected = (value) => {
        try {
          step(generator.throw(value));
        } catch (e) {
          reject(e);
        }
      };
      var step = (x) => x.done ? resolve(x.value) : Promise.resolve(x.value).then(fulfilled, rejected);
      step((generator = generator.apply(__this, __arguments)).next());
    });
  };

  // src/tree-renderer.ts
  function renderNode(node) {
    return __async(this, null, function* () {
      const componentName = node.component || "";
      if (node.componentKey) {
        return yield renderComponentInstance(node);
      }
      const direction = LAYOUT_COMPONENTS[componentName];
      if (direction) {
        return yield renderLayoutFrame(node, direction, componentName);
      }
      return yield renderFallbackFrame(node, componentName);
    });
  }
  function renderComponentInstance(node) {
    return __async(this, null, function* () {
      try {
        var component = yield figma.importComponentByKeyAsync(node.componentKey);
      } catch (e) {
        console.warn("Could not import component " + node.component + " (" + node.componentKey + "), using fallback frame");
        return yield renderFallbackFrame(node, node.component || "");
      }
      var instance = component.createInstance();
      applyProperties(instance, node);
      if (node.isImage && node.textProperties) {
        const prompt = Object.values(node.textProperties).find((v) => typeof v === "string" && v.length > 0);
        if (prompt) {
          pendingImageFills.push({ nodeId: instance.id, prompt });
        }
      }
      const overflow = yield renderSlotChildren(instance, node);
      if (overflow.length === 0) return instance;
      const wrapper = figma.createFrame();
      wrapper.name = node.component || "Wrapper";
      wrapper.layoutMode = "VERTICAL";
      wrapper.primaryAxisSizingMode = "AUTO";
      wrapper.counterAxisSizingMode = "AUTO";
      wrapper.itemSpacing = 0;
      wrapper.fills = [];
      wrapper.appendChild(instance);
      for (const child of overflow) {
        wrapper.appendChild(child);
      }
      return wrapper;
    });
  }
  function applyProperties(instance, node) {
    var _a, _b, _c;
    const instanceProps = instance.componentProperties;
    const toSet = {};
    const keyMap = /* @__PURE__ */ new Map();
    for (const figmaKey of Object.keys(instanceProps)) {
      const normalized = figmaKey.replace(/#[\d:]+$/, "").trim();
      keyMap.set(normalized.toLowerCase(), figmaKey);
    }
    if (node.variantProperties) {
      for (const [name, value] of Object.entries(node.variantProperties)) {
        const figmaKey = keyMap.get(name.toLowerCase());
        if (figmaKey && ((_a = instanceProps[figmaKey]) == null ? void 0 : _a.type) === "VARIANT") {
          toSet[figmaKey] = value;
        }
      }
    }
    if (node.textProperties) {
      for (const [name, value] of Object.entries(node.textProperties)) {
        const figmaKey = keyMap.get(name.toLowerCase());
        if (figmaKey && ((_b = instanceProps[figmaKey]) == null ? void 0 : _b.type) === "TEXT") {
          toSet[figmaKey] = String(value);
        }
      }
    }
    if (node.booleanProperties) {
      for (const [name, value] of Object.entries(node.booleanProperties)) {
        const figmaKey = keyMap.get(name.toLowerCase());
        if (figmaKey && ((_c = instanceProps[figmaKey]) == null ? void 0 : _c.type) === "BOOLEAN") {
          toSet[figmaKey] = value;
        }
      }
    }
    if (Object.keys(toSet).length > 0) {
      instance.setProperties(toSet);
    }
  }
  function renderLayoutFrame(node, direction, name) {
    return __async(this, null, function* () {
      const frame = figma.createFrame();
      frame.name = name;
      frame.layoutMode = direction;
      frame.primaryAxisSizingMode = "AUTO";
      frame.counterAxisSizingMode = "AUTO";
      frame.itemSpacing = 8;
      frame.fills = [];
      const children = collectChildNodes(node);
      for (const child of children) {
        const childNode = yield renderNode(child);
        frame.appendChild(childNode);
      }
      return frame;
    });
  }
  function renderFallbackFrame(node, name) {
    return __async(this, null, function* () {
      const frame = figma.createFrame();
      frame.name = name || "Frame";
      frame.layoutMode = "VERTICAL";
      frame.primaryAxisSizingMode = "AUTO";
      frame.counterAxisSizingMode = "AUTO";
      frame.itemSpacing = 8;
      frame.fills = [];
      const children = collectChildNodes(node);
      for (const child of children) {
        const childNode = yield renderNode(child);
        frame.appendChild(childNode);
      }
      return frame;
    });
  }
  function swapAndApplyProperties(instance, figmaKey, child) {
    return __async(this, null, function* () {
      if (!child.componentKey) return false;
      try {
        const keysBefore = new Set(Object.keys(instance.componentProperties));
        const swapComponent = yield figma.importComponentByKeyAsync(child.componentKey);
        instance.setProperties({ [figmaKey]: swapComponent.id });
        const propsAfter = instance.componentProperties;
        const toSet = {};
        for (const [propKey, propDef] of Object.entries(propsAfter)) {
          if (keysBefore.has(propKey)) continue;
          const baseName = propKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
          if (propDef.type === "TEXT" && child.textProperties) {
            for (const [name, value] of Object.entries(child.textProperties)) {
              if (name.toLowerCase() === baseName) {
                toSet[propKey] = String(value);
              }
            }
          } else if (propDef.type === "BOOLEAN" && child.booleanProperties) {
            for (const [name, value] of Object.entries(child.booleanProperties)) {
              if (name.toLowerCase() === baseName) {
                toSet[propKey] = value;
              }
            }
          } else if (propDef.type === "VARIANT" && child.variantProperties) {
            for (const [name, value] of Object.entries(child.variantProperties)) {
              if (name.toLowerCase() === baseName) {
                toSet[propKey] = value;
              }
            }
          }
        }
        if (Object.keys(toSet).length > 0) {
          instance.setProperties(toSet);
        }
        return true;
      } catch (e) {
        return false;
      }
    });
  }
  function renderSlotChildren(instance, node) {
    return __async(this, null, function* () {
      const overflow = [];
      const instanceProps = instance.componentProperties;
      const swapMap = /* @__PURE__ */ new Map();
      for (const [figmaKey, propDef] of Object.entries(instanceProps)) {
        if (propDef.type === "INSTANCE_SWAP") {
          const normalized = figmaKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
          swapMap.set(normalized, { figmaKey, propDef });
        }
      }
      const orderedSlots = Array.from(swapMap.entries()).sort(([a], [b]) => a.localeCompare(b, void 0, { numeric: true })).map(([, v]) => v);
      const usedSlotKeys = /* @__PURE__ */ new Set();
      for (const [key, value] of Object.entries(node)) {
        if (["component", "componentKey", "isImage", "variantProperties", "textProperties", "booleanProperties"].includes(key)) continue;
        if (!Array.isArray(value)) continue;
        const slotChildren = value.filter(
          (item) => item != null && typeof item === "object" && "component" in item
        );
        if (slotChildren.length === 0) continue;
        const slotNorm = key.toLowerCase();
        const directSwap = swapMap.get(slotNorm);
        if (slotChildren.length === 1 && directSwap) {
          const child = slotChildren[0];
          const swapped = yield swapAndApplyProperties(instance, directSwap.figmaKey, child);
          if (swapped) {
            usedSlotKeys.add(directSwap.figmaKey);
            continue;
          }
        }
        if (!directSwap) {
          let slotIndex = 0;
          for (const child of slotChildren) {
            while (slotIndex < orderedSlots.length && usedSlotKeys.has(orderedSlots[slotIndex].figmaKey)) {
              slotIndex++;
            }
            if (slotIndex >= orderedSlots.length) {
              const rendered = yield renderNode(child);
              overflow.push(rendered);
              continue;
            }
            const slot = orderedSlots[slotIndex];
            const swapped = yield swapAndApplyProperties(instance, slot.figmaKey, child);
            if (swapped) {
              usedSlotKeys.add(slot.figmaKey);
              slotIndex++;
            } else {
              const rendered = yield renderNode(child);
              overflow.push(rendered);
            }
          }
          continue;
        }
        for (const child of slotChildren) {
          const rendered = yield renderNode(child);
          overflow.push(rendered);
        }
      }
      return overflow;
    });
  }
  function collectChildNodes(node) {
    const children = [];
    for (const [key, value] of Object.entries(node)) {
      if ([
        "component",
        "componentKey",
        "isImage",
        "variantProperties",
        "textProperties",
        "booleanProperties"
      ].includes(key)) {
        continue;
      }
      if (Array.isArray(value)) {
        for (const item of value) {
          if (item && typeof item === "object" && "component" in item) {
            children.push(item);
          }
        }
      }
    }
    return children;
  }
  var pendingImageFills, LAYOUT_COMPONENTS;
  var init_tree_renderer = __esm({
    "src/tree-renderer.ts"() {
      "use strict";
      pendingImageFills = [];
      LAYOUT_COMPONENTS = {
        VStack: "VERTICAL",
        HStack: "HORIZONTAL",
        Column: "VERTICAL",
        Row: "HORIZONTAL"
      };
    }
  });

  // src/code.ts
  var require_code = __commonJS({
    "src/code.ts"(exports) {
      init_tree_renderer();
      figma.showUI(__html__, { width: 320, height: 340 });
      figma.ui.onmessage = (msg) => __async(null, null, function* () {
        if (msg.type === "render-tree") {
          try {
            pendingImageFills.length = 0;
            const rootFrame = figma.createFrame();
            rootFrame.name = msg.name || "Design GPT Import";
            rootFrame.layoutMode = "VERTICAL";
            rootFrame.primaryAxisSizingMode = "AUTO";
            rootFrame.counterAxisSizingMode = "AUTO";
            rootFrame.itemSpacing = 0;
            rootFrame.fills = [
              { type: "SOLID", color: { r: 1, g: 1, b: 1 } }
            ];
            const rendered = yield renderNode(msg.tree);
            rootFrame.appendChild(rendered);
            const viewport = figma.viewport.center;
            rootFrame.x = Math.round(viewport.x - rootFrame.width / 2);
            rootFrame.y = Math.round(viewport.y - rootFrame.height / 2);
            figma.currentPage.appendChild(rootFrame);
            figma.viewport.scrollAndZoomIntoView([rootFrame]);
            if (pendingImageFills.length > 0) {
              figma.ui.postMessage({ type: "fetch-images", fills: [...pendingImageFills] });
            }
            figma.ui.postMessage({ type: "render-done", name: msg.name });
          } catch (err) {
            figma.ui.postMessage({
              type: "render-error",
              error: err.message || String(err)
            });
          }
        } else if (msg.type === "image-data") {
          try {
            const node = figma.getNodeById(msg.nodeId);
            if (node && "fills" in node) {
              const image = figma.createImage(new Uint8Array(msg.bytes));
              node.fills = [
                { type: "IMAGE", imageHash: image.hash, scaleMode: "FILL" }
              ];
            }
          } catch (err) {
            console.warn("Failed to apply image fill to " + msg.nodeId, err);
          }
        }
      });
    }
  });
  require_code();
})();
