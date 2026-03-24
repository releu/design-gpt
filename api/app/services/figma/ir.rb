# Intermediate Representation for the Figma → React pipeline.
# Every IR node is a plain Hash with :kind as the discriminator.
# Factory methods ensure consistent shape across Resolver and Emitter.
module Figma
  module IR
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
