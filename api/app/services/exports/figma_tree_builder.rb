module Exports
  class FigmaTreeBuilder
    include ComponentNaming

    def initialize(design)
      @design = design
      @component_index = build_component_index
    end

    def build(tree)
      enrich_node(tree)
    end

    private

    def enrich_node(node)
      return node unless node.is_a?(Hash)

      component_name = node["component"]
      enriched = node.dup

      if component_name && (record = @component_index[component_name])
        case record
        when ComponentSet
          default_variant = record.default_variant
          if default_variant
            enriched["componentKey"] = default_variant.component_key
            enriched["nodeId"] = default_variant.node_id
            enriched["variantProperties"] = build_variant_properties(node, record)
          end
          enriched["textProperties"] = build_typed_properties(node, record, "TEXT")
          enriched["booleanProperties"] = build_typed_properties(node, record, "BOOLEAN")
          enriched["isImage"] = true if record.is_image
        when Component
          enriched["componentKey"] = record.component_key
          enriched["nodeId"] = record.node_id
          enriched["textProperties"] = build_typed_properties(node, record, "TEXT")
          enriched["booleanProperties"] = build_typed_properties(node, record, "BOOLEAN")
          enriched["isImage"] = true if record.is_image
        end

        slot_frames = build_slot_frames(node, record)
        enriched["_slotFrames"] = slot_frames if slot_frames.any?
      end

      # Recursively enrich children in slot arrays
      enriched.each do |key, value|
        if value.is_a?(Array) && value.any? { |v| v.is_a?(Hash) && v["component"] }
          enriched[key] = value.map { |child| enrich_node(child) }
        end
      end

      enriched
    end

    def build_variant_properties(node, component_set)
      props = {}
      (component_set.prop_definitions || {}).each do |prop_name, prop_def|
        next unless prop_def["type"] == "VARIANT"

        camel = to_prop_name(prop_name)
        value = node[camel]
        props[prop_name] = value if value
      end
      props
    end

    def build_typed_properties(node, record, type)
      prop_defs = record.respond_to?(:prop_definitions) ? record.prop_definitions : {}
      props = {}
      (prop_defs || {}).each do |prop_name, prop_def|
        if prop_def["type"] == type
          camel = to_prop_name(prop_name)
          value = node[camel]
          props[prop_name] = value unless value.nil?
        elsif type == "TEXT" && prop_def["type"] == "INSTANCE_SWAP"
          # Image prompt props: INSTANCE_SWAP pointing to #image components
          preferred = prop_def["preferredValues"] || []
          if preferred.any? { |pv| image_component_keys.include?(pv["key"]) }
            camel = to_prop_name(prop_name)
            value = node[camel]
            props[prop_name] = value unless value.nil?
          end
        end
      end
      props
    end

    def image_component_keys
      @image_component_keys ||= begin
        keys = Set.new
        figma_files = @design.design_system&.current_figma_files || []
        figma_files.each do |ff|
          ff.component_sets.select(&:is_image).each do |cs|
            keys << cs.component_key if cs.component_key
            cs.variants.each { |v| keys << v.component_key if v.component_key }
          end
          ff.components.select(&:is_image).each do |comp|
            keys << comp.component_key if comp.component_key
          end
        end
        keys
      end
    end

    # Map tree slot keys to Figma internal frame names for SLOT-type properties.
    # E.g. tree key "children" → Figma SLOT property "Scroll" → { "children" => "Scroll" }
    def build_slot_frames(node, record)
      prop_defs = record.respond_to?(:prop_definitions) ? record.prop_definitions : {}
      slots = record.respond_to?(:slots) ? (record.slots || []) : []

      # Collect SLOT-type property names from prop_definitions
      slot_prop_names = (prop_defs || {}).select { |_, d| d["type"] == "SLOT" }.keys

      mapping = {}
      # Match each tree slot key to a SLOT property name
      slots.each_with_index do |slot_def, i|
        slot_name = slot_def["name"]
        next unless slot_name && node.key?(slot_name)
        # Use positional matching: slot_def[i] → slot_prop_names[i]
        frame_name = slot_prop_names[i]
        mapping[slot_name] = frame_name if frame_name
      end

      mapping
    end

    def build_component_index
      index = {}
      figma_files = @design.design_system&.current_figma_files || []

      figma_files.each do |ff|
        ff.component_sets.reject(&:vector?).each do |cs|
          index[to_component_name(cs.name)] = cs
        end
        ff.components.reject(&:vector?).each do |comp|
          index[to_component_name(comp.name)] = comp
        end
      end

      index
    end
  end
end
