# Glossary

Terms used across all specs, design docs, and code. The whole team should use these consistently.

## Design System & Components

| Term | Meaning |
|------|---------|
| **Design System** | A named collection of one or more Figma files. The user creates it, imports Figma files into it, and selects it when generating a design. |
| **Figma File** | A single Figma file URL linked to a design system. Contains components. This is the user-facing term. |
| **Component Library** | The internal record created when a Figma file is imported. Contains all component sets, components, and variants extracted from that file. Users don't see this term — they see "Figma files" in the UI. |
| **Component Set** | A group of related component variants (e.g. Button with Size and State variants). Imported from Figma, mirrors Figma's component set structure. |
| **Component** | A standalone component that is not part of a component set. Has no variants. Imported from Figma. |
| **Variant** | One specific combination of prop values within a component set (e.g. Button/Size=M, State=hover). Imported from Figma. |
| **Props** | Properties on a component: variant (enum), text (string), boolean. Prop definitions are imported from Figma; prop values can be changed by the user (e.g. selecting a variant, editing text, toggling a boolean). |
| **Vector** | A vector-only component from Figma, displayed as SVG rather than rendered as React. Imported from Figma. |

All of the above (except Design System and Figma File) directly mirror Figma's structure — they are imported as-is and not created or edited in our UI.

## Composition Model

| Term | Meaning |
|------|---------|
| **Root Component** | A component marked with `#root` in Figma. Can be used as the top-level element in AI-generated designs. |
| **Slot** | A named placeholder inside a component where child components can be placed. A component can have multiple slots (e.g. "content", "actions", "header"). Detected from Figma Slots or INSTANCE_SWAP properties — both are valid ways to define slots in Figma. |
| **Allowed Children** | The list of components that can be placed into a specific slot. Each slot has its own allowed children list, detected from the slot's preferred values in Figma. Figma is flexible (any component can go in a slot), but we are strict — only the preferred components are allowed, so the AI knows exactly what to put where. |

## Design Generation

| Term | Meaning |
|------|---------|
| **Design** | A user's design project. Has a prompt, a linked design system, and one or more iterations. |
| **Prompt** | The user's text description of what they want to create. |
| **Iteration** | One version of a generated design. Each chat improvement creates a new iteration with updated JSX. |
| **Preview** | The live rendered output of the generated JSX, displayed in a phone or desktop frame. |
