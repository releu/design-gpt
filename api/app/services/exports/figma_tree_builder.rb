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
            enriched["variantProperties"] = build_variant_properties(node, record)
          end
          enriched["textProperties"] = build_typed_properties(node, record, "TEXT")
          enriched["booleanProperties"] = build_typed_properties(node, record, "BOOLEAN")
        when Component
          enriched["componentKey"] = record.component_key
          enriched["textProperties"] = build_typed_properties(node, record, "TEXT")
          enriched["booleanProperties"] = build_typed_properties(node, record, "BOOLEAN")
        end
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
        next unless prop_def["type"] == type

        camel = to_prop_name(prop_name)
        value = node[camel]
        props[prop_name] = value unless value.nil?
      end
      props
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
