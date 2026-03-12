interface TreeNode {
  component?: string;
  componentKey?: string;
  variantProperties?: Record<string, string>;
  textProperties?: Record<string, string | boolean>;
  booleanProperties?: Record<string, boolean>;
  [key: string]: unknown;
}

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

  // Recursively render slot children and append
  await renderSlotChildren(instance, node);

  return instance;
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

async function renderSlotChildren(
  instance: InstanceNode,
  node: TreeNode
): Promise<void> {
  const children = collectChildNodes(node);
  if (children.length === 0) return;

  // Find a suitable container inside the instance to append children
  // For now, append rendered children next to the instance in a wrapper frame
  // (Figma instances don't allow arbitrary child insertion, but we can create
  //  a group that visually represents the composition)
  if (children.length > 0) {
    // We can't directly insert into instance slots via plugin API,
    // but we render children as siblings so the user sees the full tree
    for (const child of children) {
      await renderNode(child);
      // Children are added to the page; the parent frame (created by caller) will contain them
    }
  }
}

function collectChildNodes(node: TreeNode): TreeNode[] {
  const children: TreeNode[] = [];

  for (const [key, value] of Object.entries(node)) {
    // Skip known non-child keys
    if (
      [
        "component",
        "componentKey",
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
