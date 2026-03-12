# Imports component structure from a single Figma file into the database.
# Stores raw figma_json as-is (INSTANCE nodes keep their componentId for cross-file resolution).
module Figma
  class Importer
    def initialize(figma_file)
      @figma_file = figma_file
      @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
      @file_key = figma_file.figma_file_key
      @file_name = nil
    end

    def import
      return log("No figma_file_key on FigmaFile##{@figma_file.id}") unless @file_key.present?

      log "Starting import for FigmaFile##{@figma_file.id} (file: #{@file_key})"

      # 1. Fetch the full Figma file
      file = @figma.get("/v1/files/#{@file_key}")
      @file_name = file["name"]
      document = file["document"]

      log "File: #{@file_name}"

      # Update design system with the file name
      @figma_file.update!(figma_file_name: @file_name)

      # 2. Collect component metadata from file
      component_sets_data, standalone_data = collect_components(file)
      log "Found #{component_sets_data.size} component sets, #{standalone_data.size} standalone components"

      # 3. Build key → name map for resolving preferredValues
      key_to_name = build_key_to_name_map(file)

      # 4. Enrich with full JSON from document tree
      node_index = {}
      build_node_index(document, node_index)
      enrich(component_sets_data, standalone_data, node_index, key_to_name)

      # 5. Filter empties
      component_sets_data.reject! { |_, data| empty_component_set?(data) }
      standalone_data.reject! { |_, data| empty_component?(data[:figma_json]) }
      log "After filtering: #{component_sets_data.size} component sets, #{standalone_data.size} standalone components"

      # 6. Persist
      persist_component_sets(component_sets_data)
      persist_standalone_components(standalone_data)

      log "Import complete!"
    end

    private

    def log(message)
      puts "[Figma::Importer] #{message}"
    end

    def collect_components(file)
      component_sets = {}
      standalone_components = {}

      # Process component sets and their variants
      (file["componentSets"] || {}).each do |node_id, meta|
        component_sets[node_id] = {
          node_id: node_id,
          name: meta["name"],
          description: meta["description"],
          component_key: meta["key"],
          variants: {}
        }
      end

      # Process components — either variants or standalone
      (file["components"] || {}).each do |node_id, meta|
        if meta["componentSetId"]
          set_id = meta["componentSetId"]
          if component_sets[set_id]
            component_sets[set_id][:variants][node_id] = {
              node_id: node_id,
              name: meta["name"],
              description: meta["description"],
              component_key: meta["key"]
            }
          end
        else
          standalone_components[node_id] = {
            node_id: node_id,
            name: meta["name"],
            description: meta["description"],
            component_key: meta["key"]
          }
        end
      end

      log "  #{component_sets.size} component sets with #{component_sets.values.sum { |s| s[:variants].size }} variants"
      log "  #{standalone_components.size} standalone components"

      [component_sets, standalone_components]
    end

    def enrich(component_sets, standalone_components, node_index, key_to_name = {})
      log "Enriching with full structure..."

      component_sets.each do |node_id, data|
        set_node = node_index[node_id]
        next unless set_node

        data[:prop_definitions] = strip_figma_id_suffixes(set_node["componentPropertyDefinitions"] || {})
        data[:figma_json] = set_node
        data[:slots] = extract_slots(data[:prop_definitions], key_to_name, set_node)
        data[:is_root] = data[:name].to_s.include?("#root") || data[:description].to_s.include?("#root")

        default_variant_id = find_default_variant_id(set_node, data[:prop_definitions])

        data[:variants].each do |variant_id, variant_data|
          variant_node = node_index[variant_id]
          if variant_node
            # Store raw figma_json — no detaching of external instances.
            # Cross-file dependencies are resolved at conversion time by ComponentResolver.
            variant_data[:figma_json] = variant_node
            variant_data[:is_default] = (variant_id == default_variant_id)
          end
        end

      end

      standalone_components.each do |node_id, data|
        comp_node = node_index[node_id]
        next unless comp_node

        data[:prop_definitions] = strip_figma_id_suffixes(comp_node["componentPropertyDefinitions"] || {})
        # Store raw figma_json as-is
        data[:figma_json] = comp_node
        data[:slots] = extract_slots(data[:prop_definitions], key_to_name, comp_node)
        data[:is_root] = data[:name].to_s.include?("#root") || data[:description].to_s.include?("#root")
      end
    end

    def build_node_index(node, index)
      return unless node.is_a?(Hash)

      index[node["id"]] = node if node["id"]

      (node["children"] || []).each do |child|
        build_node_index(child, index)
      end
    end

    def find_default_variant_id(set_node, prop_definitions)
      return nil unless set_node["children"]&.any?

      default_parts = []
      (prop_definitions || {}).each do |key, value|
        if value["type"] == "VARIANT" && value["defaultValue"]
          prop_name = key.split("#").first
          default_parts << "#{prop_name}=#{value['defaultValue']}"
        end
      end

      if default_parts.any?
        set_node["children"].each do |child|
          next unless child["type"] == "COMPONENT"
          if default_parts.all? { |part| child["name"]&.include?(part) }
            return child["id"]
          end
        end
      end

      set_node["children"].first&.dig("id")
    end

    # Figma appends "#nodeId" suffixes to componentPropertyDefinitions keys
    # (e.g. "Content#2:1405") to disambiguate same-name props on different nodes.
    # Strip these suffixes so stored prop_definitions have clean keys.
    def strip_figma_id_suffixes(defs)
      defs.transform_keys { |k| k.gsub(/#[\d:]+$/, "").strip }
    end

    def build_key_to_name_map(file)
      map = {}
      (file["componentSets"] || {}).each { |_, meta| map[meta["key"]] = meta["name"] if meta["key"] }
      (file["components"] || {}).each    { |_, meta| map[meta["key"]] = meta["name"] if meta["key"] }
      map
    end

    def extract_slots(prop_defs, key_to_name, node = nil)
      slots = []

      # 1. Check native Figma Slots API first
      if node.is_a?(Hash) && node["slots"].is_a?(Array) && node["slots"].any?
        node["slots"].each do |slot|
          name = slot["name"].to_s.presence || "children"
          preferred = slot["preferredValues"] || []
          children = preferred.filter_map { |pv| key_to_name[pv["key"]] }.uniq
          slots << { "name" => name, "allowed_children" => children }
        end
        return slots
      end

      # 2. Fall back to SLOT and INSTANCE_SWAP properties
      return [] unless prop_defs.is_a?(Hash)

      slot_props = prop_defs.select { |_, d| d["type"] == "SLOT" || d["type"] == "INSTANCE_SWAP" }
      slot_props.each do |prop_key, definition|
        preferred = definition["preferredValues"] || []
        children = preferred.filter_map { |pv| key_to_name[pv["key"]] }.uniq
        next unless children.any?

        # Strip Figma's #N suffix from property key to get slot name
        slot_name = prop_key.to_s.gsub(/#[\d:]+$/, "").strip
        slot_name = "children" if slot_name.empty?
        slots << { "name" => slot_name, "allowed_children" => children }
      end

      # If exactly one slot, use "children" as the name for backward compatibility
      slots.first["name"] = "children" if slots.length == 1

      slots
    end

    def empty_component_set?(data)
      return true if data[:variants].empty?

      data[:variants].values.all? do |variant|
        empty_component?(variant[:figma_json])
      end
    end

    def empty_component?(figma_json)
      return true unless figma_json.is_a?(Hash)

      children = figma_json["children"]
      container_types = %w[FRAME GROUP COMPONENT COMPONENT_SET]

      if container_types.include?(figma_json["type"])
        return true if children.nil? || children.empty?
        return children.all? { |child| empty_component?(child) }
      end

      if figma_json["type"] == "TEXT"
        return figma_json["characters"].to_s.strip.empty?
      end

      visual_types = %w[VECTOR RECTANGLE ELLIPSE LINE STAR POLYGON BOOLEAN_OPERATION]
      if visual_types.include?(figma_json["type"])
        has_fills = figma_json["fills"].is_a?(Array) && figma_json["fills"].any? { |f| f["visible"] != false }
        has_strokes = figma_json["strokes"].is_a?(Array) && figma_json["strokes"].any? { |s| s["visible"] != false }
        return !(has_fills || has_strokes)
      end

      # INSTANCE nodes are NOT empty — they reference other components
      return false if figma_json["type"] == "INSTANCE"

      false
    end

    def persist_component_sets(component_sets)
      log "Persisting #{component_sets.size} component sets..."

      existing_ids = component_sets.keys
      @figma_file.component_sets.where.not(node_id: existing_ids).destroy_all

      component_sets.each do |node_id, data|
        set = @figma_file.component_sets.find_or_initialize_by(node_id: node_id)
        attrs = {
          name: data[:name],
          description: data[:description],
          figma_file_key: @file_key,
          figma_file_name: @file_name,
          prop_definitions: data[:prop_definitions] || {},
          slots: data[:slots] || [],
          is_root: data[:is_root] || false,
          component_key: data[:component_key]
        }
        if data[:invalid]
          attrs[:status] = "error"
          attrs[:error_message] = data[:invalid_reason]
        else
          attrs[:status] = "pending"
          attrs[:error_message] = nil
        end
        begin
          set.update!(attrs)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          set = @figma_file.component_sets.find_by!(node_id: node_id)
          set.update!(attrs)
        end

        existing_variant_ids = data[:variants].keys
        set.variants.where.not(node_id: existing_variant_ids).destroy_all

        data[:variants].each do |variant_id, variant_data|
          variant = set.variants.find_or_initialize_by(node_id: variant_id)
          variant.update!(
            name: variant_data[:name],
            figma_json: variant_data[:figma_json] || {},
            is_default: variant_data[:is_default] || false,
            component_key: variant_data[:component_key]
          )
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          variant = set.variants.find_by!(node_id: variant_id)
          variant.update!(
            name: variant_data[:name],
            figma_json: variant_data[:figma_json] || {},
            is_default: variant_data[:is_default] || false,
            component_key: variant_data[:component_key]
          )
        end
      end
    end

    def persist_standalone_components(components)
      log "Persisting #{components.size} standalone components..."

      existing_ids = components.keys
      @figma_file.components.where.not(node_id: existing_ids).destroy_all

      components.each do |node_id, data|
        component = @figma_file.components.find_or_initialize_by(node_id: node_id)
        attrs = {
          name: data[:name],
          description: data[:description],
          prop_definitions: data[:prop_definitions] || {},
          figma_json: data[:figma_json] || {},
          figma_file_key: @file_key,
          figma_file_name: @file_name,
          slots: data[:slots] || [],
          is_root: data[:is_root] || false,
          component_key: data[:component_key]
        }
        if data[:invalid]
          attrs[:status] = "error"
          attrs[:error_message] = data[:invalid_reason]
        else
          attrs[:status] = "pending"
          attrs[:error_message] = nil
        end
        component.update!(attrs)
      end
    end
  end
end
