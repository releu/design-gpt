# Figma to React Conversion: Technical Challenges

This document describes the technical difficulties encountered when converting Figma designs to React components. It serves as a reference for understanding edge cases and implementation decisions.

---

## 1. Layout Model Mismatch

### Problem
Figma and CSS use fundamentally different layout paradigms:

- **Figma**: Uses absolute coordinates (`absoluteBoundingBox`) for all elements internally, with Auto Layout as an optional overlay system
- **CSS**: Uses document flow by default, with Flexbox/Grid for structured layouts and `position: absolute` as an escape hatch

### Challenges

| Figma Concept | CSS Translation | Difficulty |
|---------------|-----------------|------------|
| Auto Layout (VERTICAL/HORIZONTAL) | `display: flex` | Straightforward |
| No layoutMode (free positioning) | `position: absolute` for all children | Medium |
| Mixed layout (Auto Layout + some absolute children) | Flex container with selectively absolute children | Hard |
| `layoutPositioning: ABSOLUTE` | Must wrap in positioned div | Medium |
| Constraints (LEFT, RIGHT, CENTER, SCALE) | Various positioning strategies | Hard |

### Mixed Layout Problem
When a frame has `layoutMode: VERTICAL` but some children have `layoutPositioning: ABSOLUTE`:
- The frame must remain a flex container (not convert all children to absolute)
- Only explicitly absolute children get `position: absolute`
- Flow children continue using flexbox
- Parent needs `position: relative` as positioning context

```ruby
# Detection logic
mixed_layout = has_layout_mode && has_absolute_children && has_auto_children
```

---

## 2. Information Loss in Figma API

### Problem
The Figma REST API returns node data, but critical visual information is missing or implicit.

### Missing Data

| What's Missing | Impact | Workaround |
|----------------|--------|------------|
| Component definitions | INSTANCE nodes don't include base component styles | Fetch component separately or infer from overrides |
| Variable/token values | `boundVariables` references IDs, not resolved values | Parse variable collections or use raw values |
| Canvas background | Components appear on white canvas in Figma but have transparent background in JSON | Add default white background to COMPONENT nodes |
| Inherited styles | Child nodes don't show inherited properties | Walk up the tree or assume defaults |
| Font files | Only font names, not actual files | Must have fonts installed or mapped |

### COMPONENT vs COMPONENT_SET
```
COMPONENT_SET (container for variants)
├── COMPONENT (State=Initial)    ← Each variant is a separate COMPONENT
├── COMPONENT (State=Settings)
├── COMPONENT (State=Topup)
└── COMPONENT (State=Overview)
```

When exporting a COMPONENT_SET, Figma's image export shows all variants on a white canvas, but the JSON has transparent backgrounds for each COMPONENT.

**Solution**: Add default white background to COMPONENT nodes without fills:
```ruby
if node["type"] == "COMPONENT" && visible_fills.empty?
  styles["background"] = "#fff"
end
```

---

## 3. Image Handling Complexity

### Problem
Figma images use a transform matrix and scale modes that don't directly map to CSS.

### Image Properties

```json
{
  "type": "IMAGE",
  "scaleMode": "STRETCH",
  "imageRef": "abc123...",
  "imageTransform": [
    [scaleX, shearX, translateX],
    [shearY, scaleY, translateY]
  ]
}
```

### Scale Mode Translation

| Figma scaleMode | CSS Equivalent |
|-----------------|----------------|
| `FILL` | `background-size: cover` |
| `FIT` | `background-size: contain` |
| `STRETCH` | `background-size: 100% 100%` (but with transform, needs calculation) |
| `CROP` | `background-size: cover` with position offset |
| `TILE` | `background-repeat: repeat` |

### Transform Matrix Calculation
For `STRETCH` with `imageTransform`:

```ruby
# Transform: [[scaleX, _, translateX], [_, scaleY, translateY]]
size_x = (100.0 / scale_x).round(2)  # If scale is 0.5, size is 200%
size_y = (100.0 / scale_y).round(2)
pos_x = (-translate_x * size_x).round(2)
pos_y = (-translate_y * size_y).round(2)

styles["background-size"] = "#{size_x}% #{size_y}%"
styles["background-position"] = "#{pos_x}% #{pos_y}%"
```

### Image Reference Resolution
Images are referenced by `imageRef` hash. Must:
1. Collect all `imageRef` values during tree traversal
2. Call Figma API `GET /v1/files/:key/images` to get URLs
3. Map `imageRef` → URL before rendering

---

## 4. Stacking Order (Z-Index)

### Problem
Figma renders children in DOM order (later children on top). CSS doesn't automatically preserve this for positioned elements.

### Figma Behavior
```
Frame
├── Child 0 (bottom)
├── Child 1
├── Child 2
└── Child 3 (top)
```

### CSS Issue
With `position: absolute`, all children default to `z-index: auto`, and stacking becomes unpredictable.

### Solution
Add explicit z-index based on child order:
```ruby
children.map.with_index do |child, idx|
  if needs_absolute_wrapper
    @css_rules[wrapper_class] = {
      "position" => "absolute",
      "z-index" => idx.to_s,
      # ... position properties
    }
  end
end
```

---

## 5. Text Rendering Differences

### Problem
Browsers and Figma render text differently, even with identical fonts.

### Differences

| Aspect | Figma | Browser |
|--------|-------|---------|
| Line height | Exact pixel value | May vary by font metrics |
| Letter spacing | Percentage or pixels | Pixels only |
| Text truncation | `textTruncation: ENDING` | `text-overflow: ellipsis` + setup |
| Vertical alignment | Precise baseline control | Limited control |
| Anti-aliasing | Figma's renderer | Browser/OS dependent |

### Text Truncation Setup
```css
/* Figma: textTruncation: "ENDING" */
overflow: hidden;
text-overflow: ellipsis;
white-space: nowrap;
```

### Long Text Handling
```css
word-wrap: break-word;
overflow-wrap: break-word;
```

### Typical Impact
Text rendering differences account for 2-4% visual diff even with perfect layout, due to:
- Sub-pixel positioning differences
- Font hinting variations
- Line break decisions

---

## 6. Vector/Icon Detection

### Problem
Vector-only frames (icons) should be exported as SVG, not converted to HTML elements.

### Detection Logic
```ruby
def icon_frame?(node)
  return false unless CONTAINER_TYPES.include?(node["type"])
  
  children = node["children"] || []
  return false if children.empty?
  
  # Must NOT have image fills (those are photos, not icons)
  has_image_fill = children.any? do |child|
    (child["fills"] || []).any? { |f| f["type"] == "IMAGE" }
  end
  return false if has_image_fill
  
  # All children must be vectors
  children.all? { |child| vector_only?(child) }
end
```

### Vector Types
```ruby
VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON]
```

### SVG Export
For detected icon frames:
1. Call Figma API `GET /v1/images/:key?ids=...&format=svg`
2. Inline the SVG in the React component
3. Apply size from `absoluteBoundingBox`

---

## 7. Visibility and Hidden Layers

### Problem
Figma JSON includes `visible: false` nodes, but Figma's image export may render them differently.

### Behavior
```ruby
return "" if node["visible"] == false
```

### Edge Cases
- Reference images exported when layer was visible
- Layer visibility controlled by component properties
- Conditional visibility in prototypes

### Fill Visibility
```ruby
visible_fills = fills.select { |f| f["visible"] != false }
```

---

## 8. Effects and Shadows

### Problem
Figma effects don't map 1:1 to CSS.

### Drop Shadow
```json
{
  "type": "DROP_SHADOW",
  "offset": { "x": 0, "y": 4 },
  "radius": 8,
  "spread": 0,
  "color": { "r": 0, "g": 0, "b": 0, "a": 0.1 }
}
```

```css
box-shadow: 0px 4px 8px 0px rgba(0, 0, 0, 0.1);
```

### Inner Shadow
```css
box-shadow: inset 0px 4px 8px 0px rgba(0, 0, 0, 0.1);
```

### Layer Blur
Figma's layer blur requires `filter: blur()`, but this affects children too. May need wrapper elements.

### Background Blur
Requires `backdrop-filter: blur()` which has browser support limitations.

---

## 9. Testing Challenges

### Viewport Issues
Side-by-side comparison layouts need large viewports:
```javascript
await page.setViewport({ 
  width: 4000,  // Must fit Original + React panels
  height: 3000,
  deviceScaleFactor: 1
});
```

### Pixel Comparison Threshold
Anti-aliasing differences require tolerance:
```javascript
pixelmatch(img1, img2, diff, width, height, { 
  threshold: 0.15  // 0.1 too strict for text rendering
});
```

### Acceptable Diff
- **< 2%**: Excellent, mostly anti-aliasing
- **2-5%**: Good, minor layout/text differences
- **5-10%**: Issues present, investigate
- **> 10%**: Significant problems

---

## 10. Performance Considerations

### Large Designs
- Deep nesting creates many CSS classes
- SVG inlining increases bundle size
- Image fetching requires batching API calls

### Optimization Strategies
- Cache Figma API responses
- Deduplicate identical styles
- Lazy load images
- Consider CSS-in-JS for scoping

---

## Summary

The fundamental challenge is bridging two different paradigms:

| Figma | Web |
|-------|-----|
| Pixel-perfect visual tool | Document layout system |
| Absolute positioning native | Flow-based layout native |
| Single renderer | Multiple browsers/OS |
| Design-time tool | Runtime rendering |

Success requires handling hundreds of edge cases and accepting that ~2-5% visual difference is often unavoidable due to text rendering and anti-aliasing differences between Figma's renderer and browsers.
