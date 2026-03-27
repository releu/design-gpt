/**
 * Client-side port of /api/app/services/json_to_jsx.rb
 * Converts a JSON component tree into JSX string.
 */

const PRIORITY_PROPS = ["id", "className", "variant", "size", "disabled", "style"];

export function jsonToJsx(tree) {
  if (!tree || typeof tree !== "object") return "";
  return renderNode(tree, 0).trimEnd();
}

function renderNode(node, depth) {
  const element = node.component;
  if (!element) return "";

  const regularProps = {};
  const slotProps = {};

  for (const [k, v] of Object.entries(node)) {
    if (k === "component") continue;
    if (Array.isArray(v) && v.some((x) => x && typeof x === "object" && x.component)) {
      slotProps[k] = v;
    } else {
      regularProps[k] = v;
    }
  }

  const indent = "  ".repeat(depth);
  const open = `<${element}${propsStr(element, regularProps)}`;

  const innerParts = [];
  for (const [slotName, slotContent] of Object.entries(slotProps)) {
    const rendered = renderChildren(slotContent, depth + 2);
    if (!rendered) continue;
    const slotIndent = "  ".repeat(depth + 1);
    innerParts.push(`${slotIndent}<Slot name="${slotName}">\n${rendered}${slotIndent}</Slot>\n`);
  }
  const inner = innerParts.join("");

  if (!inner) return `${indent}${open} />\n`;
  return `${indent}${open}>\n${inner}${indent}</${element}>\n`;
}

function renderChildren(c, depth) {
  if (c === null || c === undefined || c === false || c === "") return "";

  if (typeof c === "string" || typeof c === "number") {
    return textLine(c, depth);
  }

  if (Array.isArray(c)) {
    return c
      .map((x) => {
        if (x && typeof x === "object" && x.component) {
          return renderNode(x, depth);
        }
        return textLine(x, depth);
      })
      .join("");
  }

  if (typeof c === "object" && c.component) {
    return renderNode(c, depth);
  }

  return textLine(String(c), depth);
}

function textLine(text, depth) {
  return `${"  ".repeat(depth)}${text}\n`;
}

function propsStr(element, props) {
  const parts = serializeProps(element, props);
  return parts.length ? " " + parts.join(" ") : "";
}

function serializeProps(element, props) {
  const keys = Object.keys(props).filter((k) => {
    const v = props[k];
    return v !== null && v !== undefined && !(typeof v === "string" && v === "");
  });

  keys.sort((a, b) => {
    const rankA = propRank(a);
    const rankB = propRank(b);
    if (rankA !== rankB) return rankA - rankB;
    return a.localeCompare(b);
  });

  const result = [];
  for (const k of keys) {
    const v = props[k];
    if (typeof v === "boolean") {
      if (v === false) continue;
      result.push(`${k}={true}`);
    } else {
      result.push(`${k}=${serializePropValue(k, v)}`);
    }
  }
  return result;
}

function propRank(k) {
  if (PRIORITY_PROPS.includes(k)) return 0;
  if (k.startsWith("aria-") || k.startsWith("data-")) return 1;
  return 2;
}

function serializePropValue(key, val) {
  if (val === null || val === undefined) return "{null}";

  if (typeof val === "string") {
    if (val.startsWith("__id:")) {
      return `{${val.slice(5)}}`;
    }
    if (key.endsWith("Component") && /^[A-Z]/.test(val)) {
      return `{${val}}`;
    }
    if (val.includes('"')) {
      return `{"${val.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"}`;
    }
    return `"${val}"`;
  }

  if (typeof val === "number") return `{${val}}`;
  if (typeof val === "boolean") return val ? "{true}" : "{false}";

  if (key === "style" && typeof val === "object" && !Array.isArray(val)) {
    return `{{${JSON.stringify(val)}}}`;
  }

  return `{${JSON.stringify(val)}}`;
}
