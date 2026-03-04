# AI Schema View

> No direct Figma mockup exists for this view. It appears within the design system modal's right pane when "AI Schema" is selected in the left sidebar. The specification comes from `04-design-system-management.feature`.

---

## Purpose

The AI Schema view shows a visual representation of the component tree that the AI can generate. It displays which components are marked as root and what children each root component can contain, forming a tree that represents all valid component structures.

This view helps users understand how their component library will be used by the AI during design generation.

---

## Context

This view appears in the right pane of the design system modal (`06-design-system-modal.md`) when the user clicks "AI Schema" in the left sidebar. The left sidebar gains an additional item under the "general" section:

```
general
  overview
  ai schema   <-- new item
figma-file-name
  Component A
  Component B
  ...
```

---

## Layout

### Normal State (root components exist)

```
+----------------------------------------------+
| ai schema                                     |
| Components reachable from root                |
|                                               |
| Page (root)                                   |
| +-- Title                                     |
| +-- Text                                      |
| +-- Card                                      |
|     +-- Title                                 |
|     +-- Button                                |
|                                               |
| ListContainer (root)                          |
| +-- CardItem                                  |
|                                               |
+----------------------------------------------+
```

### Specifications

- **Title**: "ai schema" -- `--text-primary`, 16px, bold
- **Subtitle**: "Components reachable from root" -- `--text-secondary`, 13px
- **Tree display**:
  - Root components are listed at the top level with a "(root)" label in `--text-secondary`
  - Root component names: `--text-primary`, 14px, bold
  - Children are indented ~24px from their parent with a tree-branch indicator (`+--`)
  - Child component names: `--text-primary`, 14px, normal weight
  - If a child component itself has `allowed_children`, its children are shown nested below it (recursive)
  - Tree lines use `--text-secondary` color
- **Vertical spacing**: `--sp-1` (4px) between tree nodes
- **Scrollable**: If the tree is tall, the right pane scrolls independently

### Empty State (no root components)

```
+----------------------------------------------+
| ai schema                                     |
|                                               |
|                                               |
|   No root components found.                   |
|   Mark components with #root in Figma.        |
|                                               |
|                                               |
+----------------------------------------------+
```

- **Message**: "No root components found." -- `--text-primary`, 14px
- **Help text**: "Mark components with #root in Figma." -- `--text-secondary`, 13px
- Both centered vertically and horizontally in the right pane

---

## States

| State                     | Description                                              |
|---------------------------|----------------------------------------------------------|
| Normal                    | Tree displayed with root components and their children   |
| Empty (no roots)          | Message prompting user to mark components with #root     |
| Single root               | One root component with its child tree                   |
| Multiple roots            | Multiple root components, each with their child trees    |
| Deep nesting              | Children of children shown with increasing indentation   |

---

## Interactions

| Action                           | Result                                              |
|----------------------------------|-----------------------------------------------------|
| Click "ai schema" in left sidebar| Right pane switches to this view                    |
| Click a component name in tree   | Optionally: navigate to that component's detail view|
| Scroll                           | Right pane scrolls if tree overflows                |

---

## Spec Coverage

- `04-design-system-management.feature`: "View AI Schema shows component tree reachable from root" -- tree starting from root, children listed
- `04-design-system-management.feature`: "Design system with no root components shows empty AI Schema" -- empty state message
