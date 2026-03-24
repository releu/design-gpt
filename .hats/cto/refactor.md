# Developer Plan: Split ReactFactory into Resolver → IR → Emitter

## Context

Read `.hats/cto/refactor.md` (the CTO rationale) first. This document is the step-by-step implementation plan.

`ReactFactory` (1900 lines) is a single class that mixes component resolution with JSX generation. We're splitting it into three files:

| File | Lines (est.) | Responsibility |
|------|-------------|----------------|
| `resolver.rb` | ~650 | Figma JSON → IR (plain hashes) |
| `emitter.rb` | ~550 | IR → JSX + CSS strings |
| `react_factory.rb` | ~100 | Orchestration: Resolver → Emitter → compile |

**The IR** is a recursive hash tree where every node is already fully resolved — no lookups, no ambiguity. The emitter just walks it and prints code.

---

## Ground Rules

1. **TDD is mandatory.** See CTO decision [15] in `cto2team.md`. Developer owns RSpec tests. Every step either keeps existing tests green or adds new tests BEFORE writing the implementation. Red → green → commit. No exceptions.
2. **Zero behavior change.** After each step, ALL existing specs (`react_factory_*_spec.rb`, `resolver_spec.rb`, `emitter_spec.rb`) and the pipeline test (`rake figma2react:test`) must pass with identical output.
3. **New code = new specs first.** When adding `Resolver#resolve_node` (Step 4) and `Emitter#emit_node` (Step 5), write the spec file BEFORE the implementation. Watch the tests fail. Then make them pass. This is non-negotiable.
4. **Move code, don't rewrite it.** Copy methods verbatim first, wire them up, verify tests pass, then clean up.
5. **One commit per step.** If a step breaks tests, revert and investigate — don't stack fixes on top.
6. **Don't touch `style_extractor.rb` or `html_converter.rb`** in this refactor. They stay as-is.
7. **QA is a separate concern.** Developer does NOT write Playwright/E2E tests. After this refactor ships, Developer posts a summary to `dev2qa.md` so QA can verify nothing broke from the user's side. But Developer's job is done when `make test-api` is green and pipeline output is identical.

---

## Step 1: Define the IR schema

Create `api/app/services/figma/ir.rb` with a module that documents the IR node structure as factory methods. This gives us a single place to understand all node kinds.

```ruby
# api/app/services/figma/ir.rb
module Figma
  module IR
    # Every IR node is a plain Hash with :kind as the discriminator.
    # Factory methods ensure consistent shape.

    def self.frame(node_id:, name:, styles:, children:, visible: true, visibility_prop: nil, data_component: nil)
      { kind: :frame, node_id: node_id, name: name, styles: styles,
        children: children, visible: visible, visibility_prop: visibility_prop,
        data_component: data_component }
    end

    def self.text(node_id:, name:, styles:, text_content: nil, text_prop: nil, visible: true, visibility_prop: nil)
      { kind: :text, node_id: node_id, name: name, styles: styles,
        text_content: text_content, text_prop: text_prop,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.shape(node_id:, name:, styles:, visible: true, visibility_prop: nil)
      { kind: :shape, node_id: node_id, name: name, styles: styles,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.component_ref(node_id:, name:, component_name:, prop_overrides: {}, visible: true, visibility_prop: nil)
      { kind: :component_ref, node_id: node_id, name: name,
        component_name: component_name, prop_overrides: prop_overrides,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.slot(node_id:, name:, prop_name:, visible: true, visibility_prop: nil)
      { kind: :slot, node_id: node_id, name: name, prop_name: prop_name,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.icon_swap(node_id:, name:, prop_name:, style_overrides: {}, visible: true, visibility_prop: nil)
      { kind: :icon_swap, node_id: node_id, name: name, prop_name: prop_name,
        style_overrides: style_overrides,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.image_swap(node_id:, name:, prop_name:, styles: {}, visible: true, visibility_prop: nil)
      { kind: :image_swap, node_id: node_id, name: name, prop_name: prop_name,
        styles: styles, visible: visible, visibility_prop: visibility_prop }
    end

    def self.svg_inline(node_id:, name:, styles:, svg_content:, visible: true, visibility_prop: nil)
      { kind: :svg_inline, node_id: node_id, name: name, styles: styles,
        svg_content: svg_content,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.png_inline(node_id:, name:, styles:, png_data:, visible: true, visibility_prop: nil)
      { kind: :png_inline, node_id: node_id, name: name, styles: styles,
        png_data: png_data,
        visible: visible, visibility_prop: visibility_prop }
    end

    def self.unresolved(node_id:, name:, styles:, instance_name:, visible: true)
      { kind: :unresolved, node_id: node_id, name: name, styles: styles,
        instance_name: instance_name, visible: visible }
    end

    # Top-level wrapper for a resolved component
    def self.component(name:, react_name:, props:, tree:, imports: [], is_image: false, is_svg: false,
                       svg_content: nil, has_slot: false, nested_props: {})
      { kind: :component, name: name, react_name: react_name, props: props,
        tree: tree, imports: imports, is_image: is_image, is_svg: is_svg,
        svg_content: svg_content, has_slot: has_slot, nested_props: nested_props }
    end

    # Top-level wrapper for a multi-variant component set
    def self.multi_variant(name:, react_name:, variant_prop_names:, prop_definitions:, variants:)
      { kind: :multi_variant, name: name, react_name: react_name,
        variant_prop_names: variant_prop_names, prop_definitions: prop_definitions,
        variants: variants }
    end

    # One variant within a multi-variant set
    def self.variant_entry(index:, variant_properties:, props:, tree:, imports: [],
                           has_slot: false, nested_props: {}, variant_record: nil)
      { kind: :variant_entry, index: index, variant_properties: variant_properties,
        props: props, tree: tree, imports: imports, has_slot: has_slot,
        nested_props: nested_props, variant_record: variant_record }
    end
  end
end
```

**Test:** `rails runner "puts Figma::IR.frame(node_id: '1', name: 'x', styles: {}, children: [])"` — should print the hash. No behavior change to existing code.

**Commit:** `Add IR schema module with factory methods for all node kinds`

---

## Step 2: Create Resolver — extract lookup table building

Create `api/app/services/figma/resolver.rb`. Start by moving ONLY the indexing logic (lines 34-76 of `react_factory.rb`).

```ruby
# api/app/services/figma/resolver.rb
module Figma
  class Resolver
    include Figma::StyleExtractor

    attr_reader :components_by_node_id, :component_sets_by_node_id,
                :variants_by_node_id, :node_id_to_component_set,
                :component_key_by_node_id, :variants_by_component_key,
                :svg_assets_by_name, :inline_svgs_by_node_id, :inline_pngs_by_node_id

    def initialize(figma_file)
      @figma_file = figma_file
      # ... (all the instance variables from ReactFactory#initialize)
      build_lookup_tables
      build_svg_asset_cache
      build_inline_svg_cache
    end

    private

    def build_lookup_tables
      # Move lines 38-68 from generate_all verbatim
    end

    def build_svg_asset_cache
      # Move build_svg_asset_cache from ReactFactory verbatim
    end

    def build_inline_svg_cache
      # Move build_inline_svg_cache from ReactFactory verbatim
    end

    # Move these helper methods verbatim:
    # - collect_all_node_ids
    # - build_node_id_cache
    # - image_component_keys
    # - normalize_icon_name (if defined here — check where it lives)
  end
end
```

Then update `ReactFactory` to use Resolver for lookups:

```ruby
def generate_all
  @batch_mode = true
  resolver = Figma::Resolver.new(@figma_file)

  # Copy lookup tables from resolver (temporary bridge — removed in later steps)
  @components_by_node_id = resolver.components_by_node_id
  @component_sets_by_node_id = resolver.component_sets_by_node_id
  # ... etc for all lookup tables

  # Rest of generate_all stays the same
  component_sets = @figma_file.component_sets.to_a
  component_sets.each { |cs| generate_component_set(cs) }
  # ...
end
```

**Test:** Run all `react_factory_*_spec.rb` specs + `rake figma2react:test`. Output must be identical.

**Commit:** `Extract Resolver: move lookup table building out of ReactFactory`

---

## Step 3: Move resolution methods to Resolver

Move these methods from ReactFactory to Resolver (copy verbatim, don't refactor):

| Method | Lines | What it does |
|--------|-------|-------------|
| `extract_props` | 307-361 | Prop definitions → typed prop hash |
| `build_slot_map` | 494-537 | Pre-scan for slot nodes |
| `collect_instances` | 545-563 | Collect referenced component IDs |
| `collect_nested_instance_props` | 565-627 | Nested detached instance props |
| `find_component_set_for_detached` | 1065-1074 | Detached instance → component set |
| `find_component_set_by_any_node_id` | 1043-1053 | Any node ID → component set |
| `find_node_by_component_id` | 1055-1063 | Tree search by componentId |
| `find_svg_for_detached` | 1098-1152 | SVG lookup for detached nodes |
| `extract_original_child_ids` | 1076-1087 | Extract original IDs from detached |
| `find_text_nodes_with_reference` | 998-1012 | Find text nodes by reference key |
| `find_nodes_with_main_component_reference` | 1027-1041 | Find nodes by mainComponent ref |
| `slot_instance?` | 400-407 | Is this node a slot? |
| `instance_swap_prop_name` | 412-426 | Get INSTANCE_SWAP prop name |
| `image_swap_instance?` | 469-478 | Is this an image swap? |
| `find_prop_for_reference` | 383-385 | Lookup prop by reference key |
| `find_prop_definition` | 390-392 | Lookup prop definition by key |
| `strip_ref_suffix` | 394-396 | Strip Figma #N:M suffixes |
| `to_prop_name` | 363-381 | Clean name → camelCase prop name |
| `to_component_name` | (wherever defined) | Name → PascalCase component name |
| `extract_instance_style_overrides` | 428-465 | Extract fill/size overrides from instance |
| `extract_overridden_props` | 955-996 | Props overridden by instance |
| `resolve_instance_component_name` | 1413-1434 | 4-level resolution → name |
| `lookup_component_set_name_for_variant` | 1154-1183 | Figma API cache lookup |
| `extract_icon_name_from_children` | 1185-1215 | Guess icon name from child nodes |
| `track_unresolved_instance` | 1301-1304 | Record unresolved warning |
| `save_unresolved_warnings` | 1281-1299 | Persist warnings to DB |

In ReactFactory, replace each moved method with a delegation:

```ruby
# Temporary bridge — delegate to resolver
def extract_props(prop_definitions, variant_tree = nil)
  @resolver.extract_props(prop_definitions, variant_tree)
end
```

**Important:** Some of these methods reference `@current_props`, `@prop_definitions`, `@nested_instance_props`, etc. — mutable state on the factory. For now, pass these as arguments or use attr_accessors on the Resolver. The goal is to move code, not redesign the state model yet.

**Test:** All specs pass. Output identical.

**Commit:** `Move resolution methods from ReactFactory to Resolver`

---

## Step 4: Add `Resolver#resolve_node` — produce IR instead of JSX

This is the core change. Add a new method `resolve_node` to Resolver that mirrors `ReactFactory#generate_node` but returns IR hashes instead of JSX strings.

Build it alongside the existing code (don't replace yet). The method signature:

```ruby
def resolve_node(node, prop_definitions: {}, current_props: {}, slot_map: {})
  return nil unless node.is_a?(Hash)
  return nil if !visible?(node, current_props) # handle visibility

  type = node["type"]
  visibility_prop = resolve_visibility_prop(node, current_props)

  case type
  when "COMPONENT", "COMPONENT_SET", "FRAME", "GROUP"
    resolve_frame(node, ...)
  when "TEXT"
    resolve_text(node, ...)
  when *VECTOR_TYPES
    resolve_shape(node, ...)
  when "SLOT"
    resolve_slot(node, ...)
  when "INSTANCE"
    resolve_instance_node(node, ...)
  else
    resolve_frame(node, ...)  # fallback
  end
end
```

Each `resolve_*` method returns an IR hash using the `Figma::IR` factory methods.

**Key difference from current code:** `resolve_instance_node` does the 4-level lookup and returns `IR.component_ref(...)`, `IR.slot(...)`, `IR.icon_swap(...)`, `IR.image_swap(...)`, or `IR.unresolved(...)` — no JSX strings.

For frames, it recurses into children:

```ruby
def resolve_frame(node, ...)
  styles = extract_frame_styles(node, is_root)

  # Check for inline PNG/SVG (same logic as current generate_frame)
  if @inline_pngs_by_node_id[node["id"]]
    return IR.png_inline(node_id: node["id"], name: node["name"], styles: styles,
                         png_data: @inline_pngs_by_node_id[node["id"]])
  end
  # ... similar for SVG

  children = (node["children"] || []).filter_map { |child| resolve_node(child, ...) }

  IR.frame(node_id: node["id"], name: node["name"], styles: styles, children: children,
           visibility_prop: visibility_prop)
end
```

**Add top-level methods:**

```ruby
def resolve_component_set(component_set)
  # Mirrors generate_component_set logic but returns IR.component or IR.multi_variant
end

def resolve_component(component)
  # Mirrors generate_component logic but returns IR.component
end
```

**Test strategy:** Write a NEW spec file `api/spec/services/figma/resolver_spec.rb` that tests `resolve_node` returns correct IR for each node type. Use the same fixture patterns as the existing `react_factory_slot_spec.rb`.

Start with these test cases (one per bug class from git history):

```ruby
# api/spec/services/figma/resolver_spec.rb
require "rails_helper"

RSpec.describe Figma::Resolver do
  fixtures :figma_files, :component_sets, :component_variants

  let(:library) { figma_files(:example_lib) }
  let(:resolver) { described_class.new(library) }

  describe "#resolve_node" do
    it "resolves FRAME to :frame with children" do
      node = { "id" => "1:1", "type" => "FRAME", "name" => "wrapper",
               "layoutMode" => "VERTICAL", "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:styles]).to include("display" => "flex", "flex-direction" => "column")
    end

    it "resolves TEXT to :text with content" do
      node = { "id" => "1:2", "type" => "TEXT", "name" => "label",
               "characters" => "Hello" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_content]).to eq("Hello")
    end

    it "resolves TEXT bound to prop" do
      node = { "id" => "1:3", "type" => "TEXT", "name" => "label",
               "characters" => "Default",
               "componentPropertyReferences" => { "characters" => "title" } }
      ir = resolver.resolve_node(node, current_props: {
        "title" => { name: "title", type: "TEXT", default_value: "Default" }
      })
      expect(ir[:kind]).to eq(:text)
      expect(ir[:text_prop]).to eq("title")
    end

    it "resolves INSTANCE to :component_ref when component exists" do
      # Create a target component set in the DB
      cs = library.component_sets.create!(
        node_id: "target:1", name: "Button",
        figma_file_key: library.figma_file_key,
        figma_file_name: library.figma_file_name
      )
      cs.variants.create!(node_id: "target:2", name: "Default",
                          is_default: true, figma_json: { "id" => "target:2", "type" => "COMPONENT" })

      # Re-build resolver to pick up new DB data
      fresh_resolver = described_class.new(library)

      node = { "id" => "1:4", "type" => "INSTANCE", "name" => "button instance",
               "componentId" => "target:1" }
      ir = fresh_resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:component_ref)
      expect(ir[:component_name]).to eq("Button")
    end

    it "resolves unresolvable INSTANCE to :unresolved" do
      node = { "id" => "1:5", "type" => "INSTANCE", "name" => "missing icon",
               "componentId" => "nonexistent:999" }
      ir = resolver.resolve_node(node)
      expect(ir[:kind]).to eq(:unresolved)
      expect(ir[:instance_name]).to eq("missing icon")
    end

    it "resolves INSTANCE_SWAP with preferredValues to :slot" do
      node = { "id" => "1:6", "type" => "INSTANCE", "name" => "content slot",
               "componentId" => "some:id",
               "componentPropertyReferences" => { "mainComponent" => "content" } }
      prop_defs = { "content" => { "type" => "INSTANCE_SWAP", "preferredValues" => [{ "type" => "COMPONENT_SET", "key" => "abc" }] } }
      ir = resolver.resolve_node(node, prop_definitions: prop_defs)
      expect(ir[:kind]).to eq(:slot)
      expect(ir[:prop_name]).to eq("content")
    end

    it "resolves hidden node as nil" do
      node = { "id" => "1:7", "type" => "FRAME", "name" => "hidden",
               "visible" => false, "children" => [] }
      ir = resolver.resolve_node(node)
      expect(ir).to be_nil
    end

    it "resolves BOOLEAN-controlled node with visibility_prop" do
      node = { "id" => "1:8", "type" => "FRAME", "name" => "conditional",
               "visible" => true, "children" => [],
               "componentPropertyReferences" => { "visible" => "showHeader" } }
      ir = resolver.resolve_node(node, current_props: {
        "showHeader" => { name: "showHeader", type: "BOOLEAN", default_value: true }
      })
      expect(ir[:kind]).to eq(:frame)
      expect(ir[:visibility_prop]).to eq("showHeader")
    end
  end
end
```

**Don't wire resolver into ReactFactory yet.** This step just builds and tests the Resolver independently.

**Commit:** `Add Resolver#resolve_node: produce IR from Figma JSON`

---

## Step 5: Create Emitter — generate JSX from IR

Create `api/app/services/figma/emitter.rb`. This is a pure code generator that takes IR and produces JSX + CSS strings.

```ruby
# api/app/services/figma/emitter.rb
module Figma
  class Emitter
    def initialize(component_name)
      @component_name = component_name
      @class_index = 0
      @css_rules = {}
    end

    def emit(ir_component)
      # Dispatches based on ir_component[:kind] (:component, :multi_variant, etc.)
      # Returns { code: "...", css_rules: {...} }
    end

    def emit_node(ir_node, depth = 0, is_root: false)
      return "" unless ir_node

      jsx = case ir_node[:kind]
      when :frame then emit_frame(ir_node, depth, is_root: is_root)
      when :text then emit_text(ir_node, depth)
      when :shape then emit_shape(ir_node, depth)
      when :component_ref then emit_component_ref(ir_node)
      when :slot then emit_slot(ir_node)
      when :icon_swap then emit_icon_swap(ir_node)
      when :image_swap then emit_image_swap(ir_node)
      when :svg_inline then emit_svg_inline(ir_node, depth)
      when :png_inline then emit_png_inline(ir_node, depth)
      when :unresolved then emit_unresolved(ir_node, depth)
      end

      # Wrap with boolean visibility
      if ir_node[:visibility_prop]
        prop = ir_node[:visibility_prop]
        if jsx.start_with?("{") && jsx.end_with?("}")
          jsx = "{#{prop} && (#{jsx[1..-2]})}"
        else
          jsx = "{#{prop} && (#{jsx})}"
        end
      end

      jsx
    end

    private

    # Each emit_* method mirrors the current generate_* but takes IR instead of raw node.
    # Move the string-building logic from ReactFactory verbatim.

    def emit_frame(ir, depth, is_root: false)
      class_name = generate_class_name(ir[:name], is_root)
      @css_rules[class_name] = ir[:styles]
      # ... generate children JSX, same indent logic as current generate_frame
    end

    def emit_text(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]
      if ir[:text_prop]
        "<span className=\"#{class_name}\">{#{ir[:text_prop]}}</span>"
      else
        "<span className=\"#{class_name}\">#{escape_jsx(ir[:text_content])}</span>"
      end
    end

    # ... etc for all node kinds
  end
end
```

**Test:** New spec file `api/spec/services/figma/emitter_spec.rb`:

```ruby
RSpec.describe Figma::Emitter do
  let(:emitter) { described_class.new("TestComponent") }

  it "emits frame with children" do
    ir = IR.frame(node_id: "1", name: "wrapper", styles: { "display" => "flex" },
                  children: [
                    IR.text(node_id: "2", name: "label", styles: {}, text_content: "Hi")
                  ])
    jsx = emitter.emit_node(ir, 0, is_root: true)
    expect(jsx).to include('className=')
    expect(jsx).to include('Hi')
  end

  it "emits component_ref" do
    ir = IR.component_ref(node_id: "1", name: "btn", component_name: "Button",
                          prop_overrides: { "label" => '"Save"' })
    jsx = emitter.emit_node(ir)
    expect(jsx).to include("<Button")
    expect(jsx).to include('label="Save"')
  end

  it "emits visibility-gated node" do
    ir = IR.frame(node_id: "1", name: "header", styles: {}, children: [],
                  visibility_prop: "showHeader")
    jsx = emitter.emit_node(ir)
    expect(jsx).to include("{showHeader && (")
  end

  it "emits unresolved as pink placeholder" do
    ir = IR.unresolved(node_id: "1", name: "x", styles: {}, instance_name: "MissingIcon")
    jsx = emitter.emit_node(ir)
    expect(jsx).to include("#FF69B4")
    expect(jsx).to include("MissingIcon")
  end
end
```

**Don't wire into ReactFactory yet.** Emitter is tested standalone.

**Commit:** `Add Emitter: generate JSX+CSS from IR nodes`

---

## Step 6: Wire it together — Resolver → Emitter replaces ReactFactory internals

Now replace the guts of `generate_component_set` and `generate_component`:

```ruby
# api/app/services/figma/react_factory.rb
module Figma
  class ReactFactory
    CODEGEN_VERSION = 3  # bump!

    def initialize(figma_file)
      @figma_file = figma_file
      @resolver = Figma::Resolver.new(figma_file)
      @generated = {}
      @pending_compilations = []
      @pending_variant_compilations = []
      @batch_mode = false
    end

    def generate_all
      @batch_mode = true
      log "Starting React code generation for ComponentLibrary##{@figma_file.id}"

      component_sets = @figma_file.component_sets.to_a
      log "Generating React code for #{component_sets.size} component sets..."
      component_sets.each_with_index do |cs, idx|
        generate_component_set(cs)
        log "  [#{idx + 1}/#{component_sets.size}] #{cs.name}" if (idx + 1) % 10 == 0 || idx == component_sets.size - 1
      end

      components = @figma_file.components.to_a
      log "Generating React code for #{components.size} standalone components..."
      components.each_with_index do |component, idx|
        generate_component(component)
        log "  [#{idx + 1}/#{components.size}] #{component.name}" if (idx + 1) % 10 == 0 || idx == components.size - 1
      end

      batch_compile_and_persist
      @resolver.save_unresolved_warnings

      log "React code generation complete! Generated #{@generated.size} components"
      @generated
    end

    def generate_component_set(component_set)
      return @generated[component_set.node_id] if @generated[component_set.node_id]

      ir = @resolver.resolve_component_set(component_set)
      return nil unless ir

      emitter = Figma::Emitter.new(ir[:react_name])
      code = emitter.emit(ir)

      compiled_code = defer_or_compile(code, ir[:react_name], "cs_#{component_set.id}",
                                       component_set.default_variant || component_set)

      @generated[component_set.node_id] = {
        name: ir[:react_name], code: code, compiled_code: compiled_code,
        node_id: component_set.node_id, type: :component_set
      }
    end

    # Similar for generate_component
    # ...

    private
    # Keep: log, defer_or_compile, compile_for_browser, preprocess_for_browser,
    #       postprocess_compiled, batch_compile_and_persist
    # Delete: everything else (moved to Resolver or Emitter)
  end
end
```

**Test:** This is the critical step. Run:
1. `bundle exec rspec spec/services/figma/` — all specs pass
2. `bundle exec rake figma2react:test` — output identical
3. If visual diff scores exist, verify they're unchanged

**Commit:** `Wire Resolver→Emitter through ReactFactory, remove old codegen methods`

---

## Step 7: Add regression test fixtures for past bugs

Go through the git history's fix commits and add a Resolver test for each bug class:

| Bug (from git log) | Fixture | Assertion |
|-----|---------|-----------|
| Cross-file INSTANCE resolution | Instance with `componentId` from sibling file | `ir[:kind] == :component_ref` |
| Variant naming collision | Two variant functions with same base name | Scoped func names in IR |
| Detached instance nested props | Detached node with `_detached` + `_was_instance` | `ir[:props]` has namespaced keys |
| INSTANCE_SWAP → slot vs icon | INSTANCE_SWAP with/without preferredValues | `:slot` vs `:icon_swap` |
| Image INSTANCE_SWAP | preferredValues all point to #image components | `:image_swap` |
| FILL sizing with max-width | Node with `layoutSizingHorizontal: "FILL"` + bbox | `styles["max-width"]` present |
| HUG+clip overflow | Node with HUG sizing + `clipsContent: true` | `styles["overflow"] == "hidden"` |
| Boolean visibility prop | Node with `componentPropertyReferences.visible` → BOOLEAN prop | `visibility_prop` set |

Each fixture is a minimal Figma JSON hash — just enough to reproduce the scenario. Store them in `api/spec/fixtures/figma/` as JSON files if they get large.

**Commit:** `Add regression test fixtures for past bug classes`

---

## File summary after refactor

```
api/app/services/figma/
├── ir.rb                 # IR schema (factory methods) — ~90 lines
├── resolver.rb           # Figma JSON → IR — ~650 lines
├── emitter.rb            # IR → JSX + CSS — ~550 lines
├── react_factory.rb      # Orchestrator — ~100 lines
├── style_extractor.rb    # CSS extraction (unchanged) — 734 lines
├── html_converter.rb     # HTML preview (unchanged) — 779 lines
├── jsx_compiler.rb       # esbuild wrapper (unchanged) — 117 lines
├── ...
```

```
api/spec/services/figma/
├── resolver_spec.rb      # NEW: IR assertions from Figma JSON fixtures
├── emitter_spec.rb       # NEW: JSX assertions from hand-crafted IR
├── react_factory_*.rb    # EXISTING: integration tests (unchanged)
```
