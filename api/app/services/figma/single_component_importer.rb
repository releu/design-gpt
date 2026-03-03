module Figma
  class SingleComponentImporter
    def initialize(component_library)
      @component_library = component_library
      @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
      @file_key = component_library.figma_file_key
    end

    # Re-import a single standalone component by its DB record
    def reimport_component(component)
      log "Re-importing component '#{component.name}' (node: #{component.node_id})"

      node = fetch_node(component.node_id)
      return unless node

      prop_defs = strip_figma_id_suffixes(node["componentPropertyDefinitions"] || {})

      component.update!(
        figma_json: node,
        prop_definitions: prop_defs,
        status: "pending"
      )

      # Re-extract SVG assets if it's a vector
      if component.vector?
        Figma::AssetExtractor.new(@component_library).extract_for_component(component)
      end

      # Re-generate React code
      factory = Figma::ReactFactory.new(@component_library)
      factory.generate_component(component)

      component.update!(status: "imported")
      log "Re-import complete for '#{component.name}'"
      component
    rescue => e
      component.update!(status: "error", error_message: e.message)
      raise
    end

    # Re-import a single component set (and its variants) by its DB record
    def reimport_component_set(component_set)
      log "Re-importing component set '#{component_set.name}' (node: #{component_set.node_id})"

      node = fetch_node(component_set.node_id)
      return unless node

      # Update variants from the fetched node's children
      existing_variant_ids = []
      (node["children"] || []).each do |child_node|
        next unless child_node["type"] == "COMPONENT"

        variant = component_set.variants.find_or_initialize_by(node_id: child_node["id"])
        variant.update!(
          name: child_node["name"],
          figma_json: child_node,
          is_default: variant.is_default # preserve existing default flag
        )
        existing_variant_ids << child_node["id"]
      end

      # Re-detect default variant
      detect_default_variant(component_set, node)

      prop_defs = strip_figma_id_suffixes(node["componentPropertyDefinitions"] || {})

      # Update the component set itself
      component_set.update!(
        prop_definitions: prop_defs
      )

      # Re-extract SVG assets if it's a vector set
      if component_set.vector?
        Figma::AssetExtractor.new(@component_library).extract_for_component_set(component_set)
      end

      # Re-generate React code
      factory = Figma::ReactFactory.new(@component_library)
      factory.generate_component_set(component_set)

      log "Re-import complete for '#{component_set.name}'"
      component_set
    end

    private

    def strip_figma_id_suffixes(defs)
      defs.transform_keys { |k| k.gsub(/#[\d:]+$/, "").strip }
    end

    def fetch_node(node_id)
      log "Fetching node #{node_id} from Figma file #{@file_key}"
      response = @figma.get("/v1/files/#{@file_key}/nodes?ids=#{URI.encode_www_form_component(node_id)}")
      nodes = response["nodes"] || {}
      node_data = nodes[node_id]
      node_data&.dig("document")
    end

    def detect_default_variant(component_set, set_node)
      prop_definitions = set_node["componentPropertyDefinitions"] || {}

      default_parts = []
      prop_definitions.each do |key, value|
        if value["type"] == "VARIANT" && value["defaultValue"]
          prop_name = key.split("#").first
          default_parts << "#{prop_name}=#{value['defaultValue']}"
        end
      end

      default_variant_id = nil
      if default_parts.any? && set_node["children"]
        set_node["children"].each do |child|
          next unless child["type"] == "COMPONENT"
          if default_parts.all? { |part| child["name"]&.include?(part) }
            default_variant_id = child["id"]
            break
          end
        end
      end

      default_variant_id ||= set_node.dig("children", 0, "id")

      if default_variant_id
        component_set.variants.update_all(is_default: false)
        component_set.variants.where(node_id: default_variant_id).update_all(is_default: true)
      end
    end

    def log(message)
      puts "[Figma::SingleComponentImporter] #{message}"
    end
  end
end
