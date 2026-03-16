"use strict";
(() => {
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __esm = (fn, res) => function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };

  // src/tree-renderer.ts
  async function findComponentByKey(key) {
    const cached = _componentCache.get(key);
    if (cached) return cached;
    try {
      const imported = await figma.importComponentByKeyAsync(key);
      console.log("[find] Imported: " + imported.name + " (key=" + key.substring(0, 8) + ")");
      _componentCache.set(key, imported);
      return imported;
    } catch (_) {
    }
    const local = figma.currentPage.findOne(
      (n) => n.type === "COMPONENT" && n.key === key
    );
    if (local) {
      console.log("[find] Found on current page: " + local.name + " (key=" + key.substring(0, 8) + ")");
      _componentCache.set(key, local);
      return local;
    }
    const MAX_PAGE_SEARCH = 5;
    let pagesSearched = 0;
    for (const page of figma.root.children) {
      if (page === figma.currentPage) continue;
      if (pagesSearched >= MAX_PAGE_SEARCH) {
        console.warn("[find] Hit page search limit (" + MAX_PAGE_SEARCH + "), stopping: key=" + key.substring(0, 8));
        break;
      }
      pagesSearched++;
      try {
        await page.loadAsync();
        const found = page.findOne(
          (n) => n.type === "COMPONENT" && n.key === key
        );
        if (found) {
          console.log("[find] Found on page '" + page.name + "': " + found.name + " (key=" + key.substring(0, 8) + ")");
          _componentCache.set(key, found);
          return found;
        }
      } catch (_) {
      }
    }
    console.warn("[find] Not found anywhere: key=" + key.substring(0, 8));
    throw new Error("Component not found: " + key);
  }
  async function renderNode(node) {
    const componentName = node.component || "";
    if (node.componentKey) {
      return await renderComponentInstance(node);
    }
    const direction = LAYOUT_COMPONENTS[componentName];
    if (direction) {
      return await renderLayoutFrame(node, direction, componentName);
    }
    return await renderFallbackFrame(node, componentName);
  }
  async function renderComponentInstance(node) {
    try {
      var component = await findComponentByKey(node.componentKey);
    } catch (e) {
      console.warn("Could not find component " + node.component + " (" + node.componentKey + "), using fallback frame");
      return await renderFallbackFrame(node, node.component || "");
    }
    var instance = component.createInstance();
    applyProperties(instance, node);
    if (node.isImage && node.textProperties) {
      const prompt = Object.values(node.textProperties).find((v) => typeof v === "string" && v.length > 0);
      if (prompt) {
        pendingImageFills.push({ nodeId: instance.id, prompt });
      }
    }
    const slotFrames = node._slotFrames || {};
    const hasSlotFrames = Object.keys(slotFrames).length > 0;
    if (hasSlotFrames) {
      const detached = instance.detachInstance();
      console.log("[slot] Detached instance '" + detached.name + "' to manipulate slot frames");
      for (const [key, frameName] of Object.entries(slotFrames)) {
        const value2 = node[key];
        if (!Array.isArray(value2)) continue;
        const slotChildren = value2.filter(
          (item) => item != null && typeof item === "object" && "component" in item
        );
        if (slotChildren.length > 0) {
          await populateSlotFrame(detached, frameName, slotChildren);
        }
      }
      return detached;
    }
    const overflow = await renderSlotChildren(instance, node);
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
  }
  function applyProperties(instance, node) {
    const instanceProps = instance.componentProperties;
    const toSet = {};
    const keyMap = /* @__PURE__ */ new Map();
    for (const figmaKey of Object.keys(instanceProps)) {
      const normalized = figmaKey.replace(/#[\d:]+$/, "").trim();
      keyMap.set(normalized.toLowerCase(), figmaKey);
    }
    const availKeys = Array.from(keyMap.keys()).join(", ");
    const treeTextKeys = Object.keys(node.textProperties || {}).join(", ");
    const treeVariantKeys = Object.keys(node.variantProperties || {}).join(", ");
    console.log("[props] " + instance.name + " \u2014 figma: [" + availKeys + "] tree-text: [" + treeTextKeys + "] tree-variant: [" + treeVariantKeys + "]");
    if (node.variantProperties) {
      for (const [name, value2] of Object.entries(node.variantProperties)) {
        const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
        const figmaKey = keyMap.get(normalized);
        if (figmaKey && instanceProps[figmaKey]?.type === "VARIANT") {
          toSet[figmaKey] = value2;
        }
      }
    }
    if (node.textProperties) {
      for (const [name, value2] of Object.entries(node.textProperties)) {
        const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
        const figmaKey = keyMap.get(normalized);
        if (figmaKey && instanceProps[figmaKey]?.type === "TEXT") {
          toSet[figmaKey] = String(value2);
        }
      }
    }
    if (node.booleanProperties) {
      for (const [name, value2] of Object.entries(node.booleanProperties)) {
        const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
        const figmaKey = keyMap.get(normalized);
        if (figmaKey && instanceProps[figmaKey]?.type === "BOOLEAN") {
          toSet[figmaKey] = value2;
        }
      }
    }
    if (Object.keys(toSet).length > 0) {
      console.log("[props] " + instance.name + " \u2014 setting " + Object.keys(toSet).length + " props");
      instance.setProperties(toSet);
    } else {
      console.log("[props] " + instance.name + " \u2014 nothing to set");
    }
  }
  async function renderLayoutFrame(node, direction, name) {
    const frame = figma.createFrame();
    frame.name = name;
    frame.layoutMode = direction;
    frame.primaryAxisSizingMode = "AUTO";
    frame.counterAxisSizingMode = "AUTO";
    frame.itemSpacing = 8;
    frame.fills = [];
    const children = collectChildNodes(node);
    for (const child of children) {
      const childNode = await renderNode(child);
      frame.appendChild(childNode);
    }
    return frame;
  }
  async function renderFallbackFrame(node, name) {
    const frame = figma.createFrame();
    frame.name = name || "Frame";
    frame.layoutMode = "VERTICAL";
    frame.primaryAxisSizingMode = "AUTO";
    frame.counterAxisSizingMode = "AUTO";
    frame.itemSpacing = 8;
    frame.fills = [];
    const children = collectChildNodes(node);
    for (const child of children) {
      const childNode = await renderNode(child);
      frame.appendChild(childNode);
    }
    return frame;
  }
  async function swapAndApplyProperties(instance, figmaKey, child) {
    if (!child.componentKey) return false;
    try {
      const keysBefore = new Set(Object.keys(instance.componentProperties));
      const swapComponent = await findComponentByKey(child.componentKey);
      instance.setProperties({ [figmaKey]: swapComponent.id });
      const propsAfter = instance.componentProperties;
      const toSet = {};
      for (const [propKey, propDef] of Object.entries(propsAfter)) {
        if (keysBefore.has(propKey)) continue;
        const baseName = propKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
        if (propDef.type === "TEXT" && child.textProperties) {
          for (const [name, value2] of Object.entries(child.textProperties)) {
            if (name.toLowerCase() === baseName) {
              toSet[propKey] = String(value2);
            }
          }
        } else if (propDef.type === "BOOLEAN" && child.booleanProperties) {
          for (const [name, value2] of Object.entries(child.booleanProperties)) {
            if (name.toLowerCase() === baseName) {
              toSet[propKey] = value2;
            }
          }
        } else if (propDef.type === "VARIANT" && child.variantProperties) {
          for (const [name, value2] of Object.entries(child.variantProperties)) {
            if (name.toLowerCase() === baseName) {
              toSet[propKey] = value2;
            }
          }
        }
      }
      if (Object.keys(toSet).length > 0) {
        instance.setProperties(toSet);
      }
      return true;
    } catch {
      return false;
    }
  }
  function findChildByName(node, name) {
    if ("children" in node) {
      for (const child of node.children) {
        if (child.name === name && "children" in child) {
          return child;
        }
        if ("children" in child) {
          const found = findChildByName(child, name);
          if (found) return found;
        }
      }
    }
    return null;
  }
  async function populateSlotFrame(instance, frameName, children) {
    const overflow = [];
    const slotFrame = findChildByName(instance, frameName);
    console.log("[slot] Looking for frame '" + frameName + "' in instance '" + instance.name + "', found: " + (slotFrame ? slotFrame.type + " '" + slotFrame.name + "'" : "null"));
    if (!slotFrame) {
      if ("children" in instance) {
        for (const c of instance.children) {
          console.log("[slot]   child: type=" + c.type + " name='" + c.name + "'");
        }
      }
      for (const child of children) {
        overflow.push(await renderNode(child));
      }
      return overflow;
    }
    if ("children" in slotFrame) {
      const defaults = [...slotFrame.children];
      for (const d of defaults) {
        try {
          d.remove();
        } catch (_) {
        }
      }
      console.log("[slot] Removed " + defaults.length + " default children from '" + frameName + "'");
    }
    for (const child of children) {
      const rendered = await renderNode(child);
      try {
        slotFrame.appendChild(rendered);
      } catch (e) {
        console.warn("[slot] appendChild failed for '" + rendered.name + "': " + e.message);
        overflow.push(rendered);
      }
    }
    return overflow;
  }
  async function renderSlotChildren(instance, node) {
    const overflow = [];
    const instanceProps = instance.componentProperties;
    const slotFrames = node._slotFrames || {};
    const swapMap = /* @__PURE__ */ new Map();
    for (const [figmaKey, propDef] of Object.entries(instanceProps)) {
      if (propDef.type === "INSTANCE_SWAP") {
        const normalized = figmaKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
        swapMap.set(normalized, { figmaKey, propDef });
      }
    }
    const orderedSlots = Array.from(swapMap.entries()).sort(([a], [b]) => a.localeCompare(b, void 0, { numeric: true })).map(([, v]) => v);
    const usedSlotKeys = /* @__PURE__ */ new Set();
    for (const [key, value2] of Object.entries(node)) {
      if (["component", "componentKey", "isImage", "variantProperties", "textProperties", "booleanProperties", "_slotFrames"].includes(key)) continue;
      if (!Array.isArray(value2)) continue;
      const slotChildren = value2.filter(
        (item) => item != null && typeof item === "object" && "component" in item
      );
      if (slotChildren.length === 0) continue;
      const frameName = slotFrames[key];
      if (frameName) {
        const slotOverflow = await populateSlotFrame(instance, frameName, slotChildren);
        overflow.push(...slotOverflow);
        continue;
      }
      const slotNorm = key.toLowerCase();
      const directSwap = swapMap.get(slotNorm);
      if (slotChildren.length === 1 && directSwap) {
        const child = slotChildren[0];
        const swapped = await swapAndApplyProperties(instance, directSwap.figmaKey, child);
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
            const rendered = await renderNode(child);
            overflow.push(rendered);
            continue;
          }
          const slot = orderedSlots[slotIndex];
          const swapped = await swapAndApplyProperties(instance, slot.figmaKey, child);
          if (swapped) {
            usedSlotKeys.add(slot.figmaKey);
            slotIndex++;
          } else {
            const rendered = await renderNode(child);
            overflow.push(rendered);
          }
        }
        continue;
      }
      for (const child of slotChildren) {
        const rendered = await renderNode(child);
        overflow.push(rendered);
      }
    }
    return overflow;
  }
  function collectChildNodes(node) {
    const children = [];
    for (const [key, value2] of Object.entries(node)) {
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
      if (Array.isArray(value2)) {
        for (const item of value2) {
          if (item && typeof item === "object" && "component" in item) {
            children.push(item);
          }
        }
      }
    }
    return children;
  }
  var pendingImageFills, LAYOUT_COMPONENTS, _componentCache;
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
      _componentCache = globalThis.__componentCache || /* @__PURE__ */ new Map();
      globalThis.__componentCache = _componentCache;
    }
  });

  // src/dev-entry.ts
  var require_dev_entry = __commonJS({
    "src/dev-entry.ts"(exports, module) {
      init_tree_renderer();
      var PLUGIN_VERSION = "v12";
      var MAX_DEV_LOGS = 200;
      if (!globalThis.__origConsoleLog) {
        globalThis.__origConsoleLog = console.log;
        globalThis.__origConsoleWarn = console.warn;
      }
      var _origLog = globalThis.__origConsoleLog;
      var _origWarn = globalThis.__origConsoleWarn;
      globalThis.__devLogs = [];
      console.log = (...args) => {
        const logs = globalThis.__devLogs;
        if (logs.length < MAX_DEV_LOGS) logs.push(args.join(" "));
        _origLog.apply(console, args);
      };
      console.warn = (...args) => {
        const logs = globalThis.__devLogs;
        if (logs.length < MAX_DEV_LOGS) logs.push("[WARN] " + args.join(" "));
        _origWarn.apply(console, args);
      };
      var _previousHandler = globalThis.__handlePluginMessage;
      try {
        globalThis.__handlePluginMessage = async (msg) => {
          if (msg.type === "render-tree") {
            try {
              globalThis.__devLogs = [];
              pendingImageFills.length = 0;
              const prevFrames = figma.currentPage.children.filter(
                (n) => n.type === "FRAME" && n.name.startsWith("[v")
              );
              for (const f of prevFrames) {
                try {
                  f.remove();
                } catch (_) {
                }
              }
              const baseName = msg.name || "Design GPT Import";
              const rootFrame = figma.createFrame();
              rootFrame.name = msg.dev ? `[${PLUGIN_VERSION}] ${baseName}` : baseName;
              rootFrame.layoutMode = "VERTICAL";
              rootFrame.primaryAxisSizingMode = "AUTO";
              rootFrame.counterAxisSizingMode = "AUTO";
              rootFrame.itemSpacing = 0;
              rootFrame.fills = [
                { type: "SOLID", color: { r: 1, g: 1, b: 1 } }
              ];
              const rendered = await renderNode(msg.tree);
              rootFrame.appendChild(rendered);
              const viewport = figma.viewport.center;
              rootFrame.x = Math.round(viewport.x - rootFrame.width / 2);
              rootFrame.y = Math.round(viewport.y - rootFrame.height / 2);
              figma.currentPage.appendChild(rootFrame);
              figma.viewport.scrollAndZoomIntoView([rootFrame]);
              if (pendingImageFills.length > 0) {
                figma.ui.postMessage({ type: "fetch-images", fills: [...pendingImageFills] });
              }
              figma.ui.postMessage({ type: "render-done", name: msg.name, logs: globalThis.__devLogs || [] });
            } catch (err) {
              figma.ui.postMessage({
                type: "render-error",
                error: err.message || String(err),
                logs: globalThis.__devLogs || []
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
          } else if (msg.type === "dev-inspect") {
            try {
              const value = eval(msg.expression);
              const serialized = typeof value === "object" ? JSON.stringify(value, null, 2) : String(value);
              figma.ui.postMessage({ type: "dev-inspect-done", value: serialized });
            } catch (e) {
              figma.ui.postMessage({ type: "dev-inspect-error", error: e.message || String(e) });
            }
          }
        };
      } catch (e) {
        globalThis.__handlePluginMessage = _previousHandler;
        throw e;
      }
    }
  });
  require_dev_entry();
})();
