# AI Schema View

> Figma: https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?node-id=2-578
>
> Appears within the design system modal's right pane when "AI Schema" is selected in the left sidebar. The specification comes from `04-design-system-management.feature`.

---

## Purpose

The AI Schema view shows a visual representation of the component tree that the AI can generate. It displays which components are marked as root, their named slots, and which children each slot can contain, forming a tree that represents all valid component structures.

This view helps users understand how their component library will be used by the AI during design generation.

---

## Context

This view appears in the right pane of the design system modal (`06-design-system-modal.md`) when the user clicks "AI Schema" in the left sidebar. The left sidebar gains an additional item under the "general" section:

The left sidebar gains an "ai schema" item under the "general" section, below "overview".

---

## Layout

### Normal State (root components exist)

### Specifications

- **Title**: "ai schema" -- black, bold
- **Subtitle**: "Slots and children reachable from root" -- darkgray
- **Tree display**:
  - Root components are listed at the top level with a "(root)" label in darkgray
  - Root component names: black, bold
  - Children are indented ~24px from their parent with a tree-branch indicator (`+--`)
  - Child component names: black, normal weight
  - Each root component lists its named slots; each slot shows its allowed children
  - If a child component itself has slots, its slots and children are shown nested below it (recursive)
  - Tree lines use darkgray color
- **Vertical spacing**: `--sp-1` (4px) between tree nodes
- **Scrollable**: If the tree is tall, the right pane scrolls independently

### Empty State (no root components)

- **Message**: "No root components found." -- black
- **Help text**: "Mark components with #root in Figma." -- darkgray
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
