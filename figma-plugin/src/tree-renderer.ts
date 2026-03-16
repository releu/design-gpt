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
    var component = await figma.importComponentByKeyAsync(node.componentKey!);
  } catch (e) {
    // Component not published as library — fall back to a labeled frame
    console.warn("Could not import component " + node.component + " (" + node.componentKey + "), using fallback frame");
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

  // Recursively render slot children and append
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

  // Variant properties
  if (node.variantProperties) {
    for (const [name, value] of Object.entries(node.variantProperties)) {
      const figmaKey = keyMap.get(name.toLowerCase());
      if (figmaKey && instanceProps[figmaKey]?.type === "VARIANT") {
        toSet[figmaKey] = value;
      }
    }
  }

  // Text properties
  if (node.textProperties) {
    for (const [name, value] of Object.entries(node.textProperties)) {
      const figmaKey = keyMap.get(name.toLowerCase());
      if (figmaKey && instanceProps[figmaKey]?.type === "TEXT") {
        toSet[figmaKey] = String(value);
      }
    }
  }

  // Boolean properties
  if (node.booleanProperties) {
    for (const [name, value] of Object.entries(node.booleanProperties)) {
      const figmaKey = keyMap.get(name.toLowerCase());
      if (figmaKey && instanceProps[figmaKey]?.type === "BOOLEAN") {
        toSet[figmaKey] = value;
      }
    }
  }

  if (Object.keys(toSet).length > 0) {
    instance.setProperties(toSet);
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

    const swapComponent = await figma.importComponentByKeyAsync(child.componentKey);
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

async function renderSlotChildren(
  instance: InstanceNode,
  node: TreeNode
): Promise<SceneNode[]> {
  const overflow: SceneNode[] = [];
  const instanceProps = instance.componentProperties;

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
    if (["component", "componentKey", "isImage", "variantProperties", "textProperties", "booleanProperties"].includes(key)) continue;
    if (!Array.isArray(value)) continue;

    const slotChildren = value.filter(
      (item: unknown): item is TreeNode => item != null && typeof item === "object" && "component" in (item as object)
    );
    if (slotChildren.length === 0) continue;

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
