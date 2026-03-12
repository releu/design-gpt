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
      yield renderSlotChildren(instance, node);
      return instance;
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
  function renderSlotChildren(instance, node) {
    return __async(this, null, function* () {
      const children = collectChildNodes(node);
      if (children.length === 0) return;
      if (children.length > 0) {
        for (const child of children) {
          yield renderNode(child);
        }
      }
    });
  }
  function collectChildNodes(node) {
    const children = [];
    for (const [key, value] of Object.entries(node)) {
      if ([
        "component",
        "componentKey",
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
  var LAYOUT_COMPONENTS;
  var init_tree_renderer = __esm({
    "src/tree-renderer.ts"() {
      "use strict";
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
      figma.ui.onmessage = (msg) => __async(exports, null, function* () {
        if (msg.type !== "render-tree") return;
        try {
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
          figma.ui.postMessage({ type: "render-done", name: msg.name });
        } catch (err) {
          figma.ui.postMessage({
            type: "render-error",
            error: err.message || String(err)
          });
        }
      });
    }
  });
  require_code();
})();
