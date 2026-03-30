// src/tree-renderer.ts
var pendingImageFills = [];
var _pendingImageSwaps = [];
function collectImageSwapFills(rootFrame2) {
  if (_pendingImageSwaps.length === 0) return;
  for (const swap of _pendingImageSwaps) {
    if ("findAll" in rootFrame2) {
      const matches = rootFrame2.findAll((n) => n.name === swap.childName);
      for (const match of matches) {
        console.log("[image] Post-render: resolved '" + swap.childName + "' to id=" + match.id);
        pendingImageFills.push({ nodeId: match.id, nodeName: match.name, prompt: swap.prompt });
      }
    }
  }
  _pendingImageSwaps.length = 0;
}
var LAYOUT_COMPONENTS = {
  VStack: "VERTICAL",
  HStack: "HORIZONTAL",
  Column: "VERTICAL",
  Row: "HORIZONTAL"
};
var _componentCache = globalThis.__componentCache || /* @__PURE__ */ new Map();
globalThis.__componentCache = _componentCache;
async function findComponent(key, nodeId, componentSetKey) {
  const cached = _componentCache.get(key);
  if (cached) return cached;
  if (nodeId) {
    try {
      const node = await figma.getNodeByIdAsync(nodeId);
      if (node && node.type === "COMPONENT") {
        console.log("[find] By nodeId: " + node.name + " (" + nodeId + ")");
        _componentCache.set(key, node);
        return node;
      }
    } catch (_) {
    }
  }
  if (componentSetKey) {
    try {
      const cs = await figma.importComponentSetByKeyAsync(componentSetKey);
      console.log("[find] Imported set: " + cs.name + " (" + cs.children.length + " variants)");
      for (const variant of cs.children) {
        if (variant.type === "COMPONENT") {
          _componentCache.set(variant.key, variant);
        }
      }
      const found = _componentCache.get(key);
      if (found) return found;
      const defaultVariant = cs.defaultVariant || cs.children[0];
      if (defaultVariant && defaultVariant.type === "COMPONENT") {
        _componentCache.set(key, defaultVariant);
        return defaultVariant;
      }
    } catch (_) {
    }
  }
  const local = figma.currentPage.findOne(
    (n) => n.type === "COMPONENT" && n.key === key
  );
  if (local) {
    console.log("[find] Found on current page: " + local.name + " (key=" + key.substring(0, 8) + ")");
    _componentCache.set(key, local);
    return local;
  }
  try {
    const imported = await figma.importComponentByKeyAsync(key);
    if (imported && imported.type === "COMPONENT") {
      console.log("[find] Imported by key: " + imported.name + " (key=" + key.substring(0, 8) + ")");
      _componentCache.set(key, imported);
      return imported;
    }
  } catch (_) {
  }
  console.warn("[find] Not found: key=" + key.substring(0, 8));
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
    var component = await findComponent(node.componentKey, node.nodeId, node.componentSetKey);
  } catch (e) {
    console.warn("Could not find component " + node.component + " (" + node.componentKey + "), using fallback frame");
    return await renderFallbackFrame(node, node.component || "");
  }
  var instance = component.createInstance();
  applyProperties(instance, node);
  if (node.isImage && node.textProperties) {
    const prompt = Object.values(node.textProperties).find((v) => typeof v === "string" && v.length > 0);
    if (prompt) {
      pendingImageFills.push({ nodeId: instance.id, nodeName: instance.name, prompt });
    }
  }
  if (node.textProperties) {
    const instanceProps = instance.componentProperties;
    for (const [figmaKey, propDef] of Object.entries(instanceProps)) {
      if (propDef.type !== "INSTANCE_SWAP") continue;
      const baseName = figmaKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
      for (const [treeName, treeValue] of Object.entries(node.textProperties)) {
        if (treeName.toLowerCase() !== baseName) continue;
        if (typeof treeValue !== "string" || treeValue.length === 0) continue;
        const childInstance = findSwapChildInstance(instance, figmaKey);
        if (childInstance) {
          console.log("[image] Found image swap child '" + childInstance.name + "' for prop '" + treeName + "', prompt: " + treeValue);
          _pendingImageSwaps.push({ childName: childInstance.name, prompt: treeValue });
        }
        break;
      }
    }
  }
  const slotFrames = node._slotFrames || {};
  const hasSlotFrames = Object.keys(slotFrames).length > 0;
  if (hasSlotFrames) {
    console.log("[slot] Populating SLOT frames on instance '" + instance.name + "' (no detach)");
    const allOverflow = [];
    for (const [key, frameName] of Object.entries(slotFrames)) {
      const value = node[key];
      if (!Array.isArray(value)) continue;
      const slotChildren = value.filter(
        (item) => item != null && typeof item === "object" && "component" in item
      );
      if (slotChildren.length > 0) {
        const overflow = await populateSlotFrame(instance, frameName, slotChildren);
        allOverflow.push(...overflow);
      }
    }
    if (allOverflow.length === 0) return instance;
    const wrapper = figma.createFrame();
    wrapper.name = node.component || "Wrapper";
    wrapper.layoutMode = "VERTICAL";
    wrapper.primaryAxisSizingMode = "AUTO";
    wrapper.counterAxisSizingMode = "AUTO";
    wrapper.itemSpacing = 0;
    wrapper.fills = [];
        wrapper.appendChild(instance);
    for (const child of allOverflow) {
          wrapper.appendChild(child);
    }
    return wrapper;
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
    for (const [name2, value] of Object.entries(node.variantProperties)) {
      const normalized = name2.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "VARIANT") {
        toSet[figmaKey] = value;
      }
    }
  }
  if (node.textProperties) {
    for (const [name2, value] of Object.entries(node.textProperties)) {
      const normalized = name2.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "TEXT") {
        toSet[figmaKey] = String(value);
      }
    }
  }
  if (node.booleanProperties) {
    for (const [name2, value] of Object.entries(node.booleanProperties)) {
      const normalized = name2.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "BOOLEAN") {
        toSet[figmaKey] = value;
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
async function renderLayoutFrame(node, direction, name2) {
  const frame = figma.createFrame();
  frame.name = name2;
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
async function renderFallbackFrame(node, name2) {
  const frame = figma.createFrame();
  frame.name = name2 || "Frame";
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
    const swapComponent = await findComponent(child.componentKey, child.nodeId);
    instance.setProperties({ [figmaKey]: swapComponent.id });
    const propsAfter = instance.componentProperties;
    const toSet = {};
    for (const [propKey, propDef] of Object.entries(propsAfter)) {
      if (keysBefore.has(propKey)) continue;
      const baseName = propKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
      if (propDef.type === "TEXT" && child.textProperties) {
        for (const [name2, value] of Object.entries(child.textProperties)) {
          if (name2.toLowerCase() === baseName) {
            toSet[propKey] = String(value);
          }
        }
      } else if (propDef.type === "BOOLEAN" && child.booleanProperties) {
        for (const [name2, value] of Object.entries(child.booleanProperties)) {
          if (name2.toLowerCase() === baseName) {
            toSet[propKey] = value;
          }
        }
      } else if (propDef.type === "VARIANT" && child.variantProperties) {
        for (const [name2, value] of Object.entries(child.variantProperties)) {
          if (name2.toLowerCase() === baseName) {
            toSet[propKey] = value;
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
function findSwapChildInstance(parent, figmaKey) {
  function walk(node) {
    if (node.type === "INSTANCE") {
      const refs = node.componentPropertyReferences;
      if (refs && refs.mainComponent === figmaKey) {
        return node;
      }
    }
    if ("children" in node) {
      for (const child of node.children) {
        const found = walk(child);
        if (found) return found;
      }
    }
    return null;
  }
  return walk(parent);
}
function findChildByName(node, name2) {
  try {
    if (!("children" in node)) return null;
    var kids = null;
    try { kids = [...node.children]; } catch(_) { return null; }
    for (const child of kids) {
      try {
        if (child.name === name2 && ("children" in child || child.type === "SLOT")) {
          return child;
        }
        if ("children" in child) {
          const found = findChildByName(child, name2);
          if (found) return found;
        }
      } catch(_) { continue; }
    }
  } catch(_) {}
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
  // Hide SLOT default children before appending new ones
  try {
    if ("children" in slotFrame) {
      for (const d of [...slotFrame.children]) {
        try { d.remove(); } catch(_) { try { d.visible = false; } catch(_2) {} }
      }
    }
  } catch(_) {}
  for (const child of children) {
    try {
      const rendered2 = await renderNode(child);
      slotFrame.appendChild(rendered2);
      try {
        rendered2.layoutSizingHorizontal = "FILL";
        rendered2.layoutSizingVertical = "HUG";
      } catch(_) {}
    } catch (e) {
      console.warn("[slot] Render/append failed for '" + (child.component || "unknown") + "' in slot '" + frameName + "': " + e.message);
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
  for (const [key, value] of Object.entries(node)) {
    if (["component", "componentKey", "isImage", "variantProperties", "textProperties", "booleanProperties", "_slotFrames"].includes(key)) continue;
    if (!Array.isArray(value)) continue;
    const slotChildren = value.filter(
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
          const rendered2 = await renderNode(child);
          overflow.push(rendered2);
          continue;
        }
        const slot = orderedSlots[slotIndex];
        const swapped = await swapAndApplyProperties(instance, slot.figmaKey, child);
        if (swapped) {
          usedSlotKeys.add(slot.figmaKey);
          slotIndex++;
        } else {
          const rendered2 = await renderNode(child);
          overflow.push(rendered2);
        }
      }
      continue;
    }
    for (const child of slotChildren) {
      const rendered2 = await renderNode(child);
      overflow.push(rendered2);
    }
  }
  return overflow;
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

// src/mcp-entry.ts
var tree = __TREE__;
var name = __NAME__ || "Design GPT Import";


for (const child of [...figma.currentPage.children]) {
  if (child.name === name) {
    try {
      child.remove();
    } catch (_) {
    }
  }
}
var rendered = await renderNode(tree);
rendered.name = name;
rendered.x = 0;
rendered.y = 0;
// rendered is already on figma.currentPage (created there by renderNode)
collectImageSwapFills(rendered);
figma.notify(`\u2713 Rendered "${name}" (${Math.round(rendered.width)}\xD7${Math.round(rendered.height)})`);
