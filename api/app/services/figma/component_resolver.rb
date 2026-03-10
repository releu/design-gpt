# Resolves Figma componentIds across multiple component libraries (Figma files).
#
# When an INSTANCE node references a componentId, the resolver looks up the
# matching component/variant across ALL component libraries linked to the project.
# This enables automatic cross-file dependency resolution:
#   - A "working file" imports Button from a library → the INSTANCE keeps componentId
#   - At conversion time, ComponentResolver finds Button's HTML/CSS from the library
#   - If the library hasn't been imported yet, the INSTANCE is rendered from its own children
#
# Usage:
#   resolver = Figma::ComponentResolver.new(project)
#   result = resolver.resolve("4654:149")
#   # => { html: "<div class='btn'>...", css: ".btn { ... }", component: <Component> }
#
module Figma
  class ComponentResolver
    def initialize(libraries_or_library)
      @figma_files = case libraries_or_library
      when FigmaFile
        [libraries_or_library]
      when Array
        libraries_or_library
      else
        []
      end

      @cache = {}
      @index_built = false
      @components_by_node_id = {}   # node_id -> Component
      @variants_by_node_id = {}     # node_id -> ComponentVariant
      @sets_by_node_id = {}         # node_id -> ComponentSet
    end

    # Resolve a Figma componentId to its converted HTML/CSS output.
    #
    # Returns nil if the component hasn't been imported or converted yet.
    # Returns a hash with :html, :css, :component/:variant keys if found.
    def resolve(component_id)
      return nil unless component_id.present?
      return @cache[component_id] if @cache.key?(component_id)

      build_index unless @index_built

      result = lookup(component_id)
      @cache[component_id] = result
      result
    end

    # Check if a componentId can be resolved (exists in any linked library)
    def resolvable?(component_id)
      build_index unless @index_built

      @components_by_node_id.key?(component_id) ||
        @variants_by_node_id.key?(component_id) ||
        @sets_by_node_id.key?(component_id)
    end

    # Return all componentIds that appear as INSTANCE references
    # in a given figma_json tree but are NOT resolvable
    def unresolved_references(figma_json)
      build_index unless @index_built

      refs = collect_instance_ids(figma_json)
      refs.reject { |id| resolvable?(id) }
    end

    private

    def build_index
      @figma_files.each do |ds|
        ds.components.each do |comp|
          @components_by_node_id[comp.node_id] = comp
        end

        ds.component_sets.includes(:variants).each do |cs|
          @sets_by_node_id[cs.node_id] = cs
          cs.variants.each do |v|
            @variants_by_node_id[v.node_id] = v
          end
        end
      end

      @index_built = true
    end

    def lookup(component_id)
      # 1. Check standalone components
      comp = @components_by_node_id[component_id]
      if comp
        return {
          html: comp.html_code,
          css: comp.css_code,
          react_code: comp.react_code,
          component: comp,
          type: :component
        }
      end

      # 2. Check variants (most common — INSTANCE references a specific variant)
      variant = @variants_by_node_id[component_id]
      if variant
        return {
          html: variant.html_code,
          css: variant.css_code,
          react_code: variant.react_code,
          variant: variant,
          component_set: variant.component_set,
          type: :variant
        }
      end

      # 3. Check component sets (less common — references the set itself)
      cs = @sets_by_node_id[component_id]
      if cs
        default = cs.default_variant
        return {
          html: default&.html_code,
          css: default&.css_code,
          react_code: default&.react_code,
          component_set: cs,
          variant: default,
          type: :component_set
        }
      end

      nil
    end

    def collect_instance_ids(node, ids = [])
      return ids unless node.is_a?(Hash)

      if node["type"] == "INSTANCE" && node["componentId"]
        ids << node["componentId"]
      end

      (node["children"] || []).each do |child|
        collect_instance_ids(child, ids)
      end

      ids.uniq
    end
  end
end
