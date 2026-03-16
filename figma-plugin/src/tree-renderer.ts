interface TreeNode {
  component?: string;
  componentKey?: string;
  isImage?: boolean;
  variantProperties?: Record<string, string>;
  textProperties?: Record<string, string | boolean>;
  booleanProperties?: Record<string, boolean>;
  [key: string]: unknown;
}

export interface PendingImageFill {
  nodeId: string;
  prompt: string;
}

export const pendingImageFills: PendingImageFill[] = [];

// Layout containers recognized from the AI tree
const LAYOUT_COMPONENTS: Record<string, "VERTICAL" | "HORIZONTAL"> = {
  VStack: "VERTICAL",
  HStack: "HORIZONTAL",
  Column: "VERTICAL",
  Row: "HORIZONTAL",
};

// Cache of component key → ComponentNode (survives across dev-eval cycles)
const _componentCache: Map<string, ComponentNode> = (globalThis as any).__componentCache || new Map();
(globalThis as any).__componentCache = _componentCache;

async function findComponentByKey(key: string): Promise<ComponentNode> {
  // Check cache first
  const cached = _componentCache.get(key);
  if (cached) return cached;

  // Try importing (works for published library components)
  try {
    const imported = await figma.importComponentByKeyAsync(key);
    console.log("[find] Imported: " + imported.name + " (key=" + key.substring(0, 8) + ")");
    _componentCache.set(key, imported);
    return imported;
  } catch (_) {}

  // Fallback: search current page only (fast, no loadAllPagesAsync)
  const local = figma.currentPage.findOne(
    (n) => n.type === "COMPONENT" && n.key === key
  ) as ComponentNode | null;
  if (local) {
    console.log("[find] Found on current page: " + local.name + " (key=" + key.substring(0, 8) + ")");
    _componentCache.set(key, local);
    return local;
  }

  // Try loading pages individually — cap at 5 to avoid hanging on large files
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
      ) as ComponentNode | null;
      if (found) {
        console.log("[find] Found on page '" + page.name + "': " + found.name + " (key=" + key.substring(0, 8) + ")");
        _componentCache.set(key, found);
        return found;
      }
    } catch (_) {}
  }

  console.warn("[find] Not found anywhere: key=" + key.substring(0, 8));
  throw new Error("Component not found: " + key);
}

export async function renderNode(
  node: TreeNode
): Promise<SceneNode> {
  const componentName = node.component || "";

  // If we have a componentKey, import the real library component
  if (node.componentKey) {
    return await renderComponentInstance(node);
  }

  // Layout container
  const direction = LAYOUT_COMPONENTS[componentName];
  if (direction) {
    return await renderLayoutFrame(node, direction, componentName);
  }

  // Unknown node — create a frame with label
  return await renderFallbackFrame(node, componentName);
}

async function renderComponentInstance(
  node: TreeNode
): Promise<SceneNode> {
  try {
    var component = await findComponentByKey(node.componentKey!);
  } catch (e) {
    console.warn("Could not find component " + node.component + " (" + node.componentKey + "), using fallback frame");
    return await renderFallbackFrame(node, node.component || "");
  }

  var instance = component.createInstance();

  // Set variant + text + boolean properties via Figma's setProperties API
  applyProperties(instance, node);

  // Collect image fill if this is an #image component
  if (node.isImage && node.textProperties) {
    const prompt = Object.values(node.textProperties).find(v => typeof v === "string" && v.length > 0);
    if (prompt) {
      pendingImageFills.push({ nodeId: instance.id, prompt: prompt as string });
    }
  }

  const slotFrames = (node._slotFrames || {}) as Record<string, string>;
  const hasSlotFrames = Object.keys(slotFrames).length > 0;

  if (hasSlotFrames) {
    // Detach instance so SLOT nodes become regular frames (avoids ghost sublayer refs)
    const detached = instance.detachInstance();
    console.log("[slot] Detached instance '" + detached.name + "' to manipulate slot frames");

    // Populate each slot frame directly
    for (const [key, frameName] of Object.entries(slotFrames)) {
      const value = node[key];
      if (!Array.isArray(value)) continue;
      const slotChildren = value.filter(
        (item: unknown): item is TreeNode => item != null && typeof item === "object" && "component" in (item as object)
      );
      if (slotChildren.length > 0) {
        await populateSlotFrame(detached as unknown as InstanceNode, frameName, slotChildren);
      }
    }
    return detached;
  }

  // No slot frames — use standard INSTANCE_SWAP slot logic
  const overflow = await renderSlotChildren(instance, node);

  if (overflow.length === 0) return instance;

  // Wrap instance + overflow children in an auto-layout frame
  const wrapper = figma.createFrame();
  wrapper.name = (node.component || "Wrapper");
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

function applyProperties(instance: InstanceNode, node: TreeNode): void {
  const instanceProps = instance.componentProperties;
  const toSet: Record<string, string | boolean> = {};

  // Build a lookup: normalized key -> actual Figma key (which may have #nodeId suffix)
  const keyMap = new Map<string, string>();
  for (const figmaKey of Object.keys(instanceProps)) {
    const normalized = figmaKey.replace(/#[\d:]+$/, "").trim();
    keyMap.set(normalized.toLowerCase(), figmaKey);
  }

  const availKeys = Array.from(keyMap.keys()).join(", ");
  const treeTextKeys = Object.keys(node.textProperties || {}).join(", ");
  const treeVariantKeys = Object.keys(node.variantProperties || {}).join(", ");
  console.log("[props] " + instance.name + " — figma: [" + availKeys + "] tree-text: [" + treeTextKeys + "] tree-variant: [" + treeVariantKeys + "]");

  // Variant properties
  if (node.variantProperties) {
    for (const [name, value] of Object.entries(node.variantProperties)) {
      const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "VARIANT") {
        toSet[figmaKey] = value;
      }
    }
  }

  // Text properties
  if (node.textProperties) {
    for (const [name, value] of Object.entries(node.textProperties)) {
      const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "TEXT") {
        toSet[figmaKey] = String(value);
      }
    }
  }

  // Boolean properties
  if (node.booleanProperties) {
    for (const [name, value] of Object.entries(node.booleanProperties)) {
      const normalized = name.replace(/#[\d:]+$/, "").trim().toLowerCase();
      const figmaKey = keyMap.get(normalized);
      if (figmaKey && instanceProps[figmaKey]?.type === "BOOLEAN") {
        toSet[figmaKey] = value;
      }
    }
  }

  if (Object.keys(toSet).length > 0) {
    console.log("[props] " + instance.name + " — setting " + Object.keys(toSet).length + " props");
    instance.setProperties(toSet);
  } else {
    console.log("[props] " + instance.name + " — nothing to set");
  }
}

async function renderLayoutFrame(
  node: TreeNode,
  direction: "VERTICAL" | "HORIZONTAL",
  name: string
): Promise<FrameNode> {
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

async function renderFallbackFrame(
  node: TreeNode,
  name: string
): Promise<FrameNode> {
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

async function swapAndApplyProperties(
  instance: InstanceNode,
  figmaKey: string,
  child: TreeNode
): Promise<boolean> {
  if (!child.componentKey) return false;
  try {
    // Snapshot property keys before the swap
    const keysBefore = new Set(Object.keys(instance.componentProperties));

    const swapComponent = await findComponentByKey(child.componentKey);
    instance.setProperties({ [figmaKey]: swapComponent.id });

    // Diff to find newly appeared properties from the swapped component
    const propsAfter = instance.componentProperties;
    const toSet: Record<string, string | boolean> = {};

    for (const [propKey, propDef] of Object.entries(propsAfter)) {
      if (keysBefore.has(propKey)) continue; // existed before swap, skip

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
  } catch {
    return false;
  }
}

// Find a named node inside an instance by traversing its children recursively.
// Matches FRAME, COMPONENT, INSTANCE, and SECTION nodes (slot frames may have any of these types).
function findChildByName(node: SceneNode, name: string): (FrameNode | InstanceNode) | null {
  if ("children" in node) {
    for (const child of (node as FrameNode).children) {
      if (child.name === name && "children" in child) {
        return child as FrameNode;
      }
      if ("children" in child) {
        const found = findChildByName(child, name);
        if (found) return found;
      }
    }
  }
  return null;
}

// Populate a slot frame inside the instance: remove defaults, add rendered children
async function populateSlotFrame(
  instance: InstanceNode,
  frameName: string,
  children: TreeNode[]
): Promise<SceneNode[]> {
  const overflow: SceneNode[] = [];
  const slotFrame = findChildByName(instance, frameName);
  console.log("[slot] Looking for frame '" + frameName + "' in instance '" + instance.name + "', found: " + (slotFrame ? slotFrame.type + " '" + slotFrame.name + "'" : "null"));
  if (!slotFrame) {
    // Debug: list instance children to understand structure
    if ("children" in instance) {
      for (const c of instance.children) {
        console.log("[slot]   child: type=" + c.type + " name='" + c.name + "'");
      }
    }
    // Can't find slot frame — all children become overflow
    for (const child of children) {
      overflow.push(await renderNode(child));
    }
    return overflow;
  }

  // Remove default placeholder children (safe after detachInstance — no ghost refs)
  if ("children" in slotFrame) {
    const defaults = [...slotFrame.children];
    for (const d of defaults) {
      try { d.remove(); } catch (_) {}
    }
    console.log("[slot] Removed " + defaults.length + " default children from '" + frameName + "'");
  }

  // Render and add each child to the slot frame.
  for (const child of children) {
    const rendered = await renderNode(child);
    try {
      slotFrame.appendChild(rendered);
    } catch (e: any) {
      console.warn("[slot] appendChild failed for '" + rendered.name + "': " + e.message);
      overflow.push(rendered);
    }
  }

  return overflow;
}

async function renderSlotChildren(
  instance: InstanceNode,
  node: TreeNode
): Promise<SceneNode[]> {
  const overflow: SceneNode[] = [];
  const instanceProps = instance.componentProperties;

  // _slotFrames maps tree keys to Figma internal frame names for SLOT-type properties
  const slotFrames = (node._slotFrames || {}) as Record<string, string>;

  // Build INSTANCE_SWAP lookup: normalized name -> figma key
  const swapMap = new Map<string, { figmaKey: string; propDef: ComponentProperties[string] }>();
  for (const [figmaKey, propDef] of Object.entries(instanceProps)) {
    if (propDef.type === "INSTANCE_SWAP") {
      const normalized = figmaKey.replace(/#[\d:]+$/, "").trim().toLowerCase();
      swapMap.set(normalized, { figmaKey, propDef });
    }
  }

  // Collect all INSTANCE_SWAP slots sorted by name for ordered distribution
  const orderedSlots = Array.from(swapMap.entries())
    .sort(([a], [b]) => a.localeCompare(b, undefined, { numeric: true }))
    .map(([, v]) => v);

  // Track which slots have been consumed
  const usedSlotKeys = new Set<string>();

  // Iterate slot arrays on the node
  for (const [key, value] of Object.entries(node)) {
    if (["component", "componentKey", "isImage", "variantProperties", "textProperties", "booleanProperties", "_slotFrames"].includes(key)) continue;
    if (!Array.isArray(value)) continue;

    const slotChildren = value.filter(
      (item: unknown): item is TreeNode => item != null && typeof item === "object" && "component" in (item as object)
    );
    if (slotChildren.length === 0) continue;

    // Check if this key has a _slotFrames mapping (SLOT-type property)
    const frameName = slotFrames[key];
    if (frameName) {
      const slotOverflow = await populateSlotFrame(instance, frameName, slotChildren);
      overflow.push(...slotOverflow);
      continue;
    }

    const slotNorm = key.toLowerCase();
    const directSwap = swapMap.get(slotNorm);

    // Single child with a directly matching INSTANCE_SWAP prop → named slot match
    if (slotChildren.length === 1 && directSwap) {
      const child = slotChildren[0];
      const swapped = await swapAndApplyProperties(instance, directSwap.figmaKey, child);
      if (swapped) {
        usedSlotKeys.add(directSwap.figmaKey);
        continue;
      }
    }

    // No direct name match — distribute children across ordered INSTANCE_SWAP slots
    if (!directSwap) {
      let slotIndex = 0;
      for (const child of slotChildren) {
        // Find next unused slot
        while (slotIndex < orderedSlots.length && usedSlotKeys.has(orderedSlots[slotIndex].figmaKey)) {
          slotIndex++;
        }
        if (slotIndex >= orderedSlots.length) {
          // No more slots — render as overflow
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
          // Swap failed — render as overflow
          const rendered = await renderNode(child);
          overflow.push(rendered);
        }
      }
      continue;
    }

    // Multiple children for a named slot, or single child swap failed — overflow
    for (const child of slotChildren) {
      const rendered = await renderNode(child);
      overflow.push(rendered);
    }
  }

  return overflow;
}

function collectChildNodes(node: TreeNode): TreeNode[] {
  const children: TreeNode[] = [];

  for (const [key, value] of Object.entries(node)) {
    // Skip known non-child keys
    if (
      [
        "component",
        "componentKey",
        "isImage",
        "variantProperties",
        "textProperties",
        "booleanProperties",
      ].includes(key)
    ) {
      continue;
    }

    if (Array.isArray(value)) {
      for (const item of value) {
        if (item && typeof item === "object" && "component" in item) {
          children.push(item as TreeNode);
        }
      }
    }
  }

  return children;
}
