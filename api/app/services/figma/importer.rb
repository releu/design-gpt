# Imports component structure from a single Figma file into the database.
# Stores raw figma_json as-is (INSTANCE nodes keep their componentId for cross-file resolution).
module Figma
  class Importer
    def initialize(figma_file)
      @figma_file = figma_file
      @figma = Figma::TokenPool.instance.primary_client
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

      # Update design system with the file name and Figma's lastModified timestamp
      # Store node_id -> component_key map for all components (enables cross-file resolution)
      component_key_map = {}
      (file["components"] || {}).each { |node_id, meta| component_key_map[node_id] = meta["key"] if meta["key"] }
      @figma_file.update!(figma_file_name: @file_name, figma_last_modified: file["lastModified"], component_key_map: component_key_map)

      # 2. Collect component metadata from file
      component_sets_data, standalone_data = collect_components(file)
      log "Found #{component_sets_data.size} component sets, #{standalone_data.size} standalone components"

      # 3. Build key → name map for resolving preferredValues
      key_to_name = build_key_to_name_map(file)

      # 3b. Build set of component keys that are #image components
      image_keys = build_image_component_keys(component_sets_data, standalone_data)

      # 4. Enrich with full JSON from document tree
      node_index = {}
      build_node_index(document, node_index)
      enrich(component_sets_data, standalone_data, node_index, key_to_name, image_keys)

      # 5. Filter empties (but keep #image components — they're intentionally empty placeholders)
      component_sets_data.reject! { |_, data| !data[:is_image] && empty_component_set?(data) }
      standalone_data.reject! { |_, data| !data[:is_image] && empty_component?(data[:figma_json]) }
      log "After filtering: #{component_sets_data.size} component sets, #{standalone_data.size} standalone components"

      # 6. Build variant JSON lookup for validation (detect instance overrides vs variant-inherited styles)
      # Include variants from sibling files so cross-file instance overrides can be detected
      variant_json_by_id = {}
      component_sets_data.each_value do |data|
        (data[:variants] || {}).each do |vid, vdata|
          variant_json_by_id[vid] = vdata[:figma_json] if vdata[:figma_json]
        end
      end
      # Include standalone components (instances reference them by node_id too)
      standalone_data.each do |node_id, data|
        variant_json_by_id[node_id] = data[:figma_json] if data[:figma_json]
      end
      if @figma_file.design_system
        @figma_file.design_system.figma_files_for_version(@figma_file.version).where.not(id: @figma_file.id).each do |sibling|
          sibling.component_sets.includes(:variants).each do |cs|
            cs.variants.each do |v|
              variant_json_by_id[v.node_id] = v.figma_json if v.figma_json.present?
            end
          end
          sibling.components.each do |comp|
            variant_json_by_id[comp.node_id] = comp.figma_json if comp.figma_json.present?
          end
        end
      end

      # 7. Persist
      persist_component_sets(component_sets_data, variant_json_by_id)
      persist_standalone_components(standalone_data, variant_json_by_id)

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

    def enrich(component_sets, standalone_components, node_index, key_to_name = {}, image_keys = Set.new)
      log "Enriching with full structure..."

      component_sets.each do |node_id, data|
        set_node = node_index[node_id]
        next unless set_node

        data[:prop_definitions] = strip_figma_id_suffixes(set_node["componentPropertyDefinitions"] || {})
        data[:figma_json] = set_node
        data[:slots] = extract_slots(data[:prop_definitions], key_to_name, set_node, image_keys)
        data[:is_root] = data[:name].to_s.include?("#root") || data[:description].to_s.include?("#root")
        data[:is_image] = data[:name].to_s.include?("#image") || data[:description].to_s.include?("#image")

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
        data[:slots] = extract_slots(data[:prop_definitions], key_to_name, comp_node, image_keys)
        data[:is_root] = data[:name].to_s.include?("#root") || data[:description].to_s.include?("#root")
        data[:is_image] = data[:name].to_s.include?("#image") || data[:description].to_s.include?("#image")
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

    def build_image_component_keys(component_sets_data, standalone_data)
      keys = Set.new
      component_sets_data.each do |_, data|
        if data[:name].to_s.include?("#image") || data[:description].to_s.include?("#image")
          keys << data[:component_key] if data[:component_key]
          data[:variants]&.each { |_, v| keys << v[:component_key] if v[:component_key] }
        end
      end
      standalone_data.each do |_, data|
        if data[:name].to_s.include?("#image") || data[:description].to_s.include?("#image")
          keys << data[:component_key] if data[:component_key]
        end
      end
      keys
    end

    def build_key_to_name_map(file)
      map = {}
      (file["componentSets"] || {}).each { |_, meta| map[meta["key"]] = meta["name"] if meta["key"] }
      (file["components"] || {}).each    { |_, meta| map[meta["key"]] = meta["name"] if meta["key"] }
      map
    end

    def extract_slots(prop_defs, key_to_name, node = nil, image_keys = Set.new)
      slots = []

      # 1. Check native Figma Slots API first
      if node.is_a?(Hash) && node["slots"].is_a?(Array) && node["slots"].any?
        node["slots"].each do |slot|
          name = slot["name"].to_s.presence || "children"
          preferred = slot["preferredValues"] || []
          # Skip slots where all preferred values are #image components
          next if preferred.any? && preferred.all? { |pv| image_keys.include?(pv["key"]) }
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
        # Skip INSTANCE_SWAP props where all preferred values are #image components
        next if preferred.any? && preferred.all? { |pv| image_keys.include?(pv["key"]) }
        children = preferred.filter_map { |pv| key_to_name[pv["key"]] }.uniq
        next unless children.any?

        # Strip Figma's #N suffix from property key to get slot name
        slot_name = prop_key.to_s.gsub(/#[\d:]+$/, "").strip
        slot_name = "children" if slot_name.empty?
        slots << { "name" => slot_name, "allowed_children" => children }
      end

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

    def persist_component_sets(component_sets, variant_json_by_id = {})
      log "Persisting #{component_sets.size} component sets..."

      existing_ids = component_sets.keys
      @figma_file.component_sets.where.not(node_id: existing_ids).destroy_all

      # Bulk upsert component sets
      set_rows = component_sets.map do |node_id, data|
        # Run validation on default variant's figma_json
        default_json = data[:variants]&.values&.find { |v| v[:is_default] }&.dig(:figma_json) ||
                       data[:variants]&.values&.first&.dig(:figma_json)
        validation_warnings = default_json ? Figma::ComponentValidator.new(default_json, is_image: data[:is_image], variant_json_by_id: variant_json_by_id).validate : []

        row = {
          figma_file_id: @figma_file.id,
          node_id: node_id,
          name: data[:name],
          description: data[:description],
          figma_file_key: @file_key,
          figma_file_name: @file_name,
          prop_definitions: data[:prop_definitions] || {},
          slots: data[:slots] || [],
          is_root: data[:is_root] || false,
          is_image: data[:is_image] || false,
          component_key: data[:component_key],
          content_hash: compute_component_set_hash(data),
          validation_warnings: validation_warnings
        }
        if data[:invalid]
          row[:status] = "error"
          row[:error_message] = data[:invalid_reason]
        else
          row[:status] = "pending"
          row[:error_message] = nil
        end
        row
      end

      ComponentSet.upsert_all(set_rows, unique_by: [:figma_file_id, :node_id]) if set_rows.any?

      # Reload sets to get IDs for variant association
      persisted_sets = @figma_file.component_sets.index_by(&:node_id)

      # Bulk upsert variants per set (need set IDs), and clean up stale ones
      component_sets.each do |node_id, data|
        set = persisted_sets[node_id]
        next unless set

        existing_variant_ids = data[:variants].keys
        set.variants.where.not(node_id: existing_variant_ids).destroy_all
      end

      variant_rows = component_sets.flat_map do |node_id, data|
        set = persisted_sets[node_id]
        next [] unless set

        data[:variants].map do |variant_id, variant_data|
          {
            component_set_id: set.id,
            node_id: variant_id,
            name: variant_data[:name],
            figma_json: variant_data[:figma_json] || {},
            is_default: variant_data[:is_default] || false,
            component_key: variant_data[:component_key],
            content_hash: compute_variant_hash(variant_data)
          }
        end
      end

      ComponentVariant.upsert_all(variant_rows, unique_by: [:component_set_id, :node_id]) if variant_rows.any?
    end

    def persist_standalone_components(components, variant_json_by_id = {})
      log "Persisting #{components.size} standalone components..."

      existing_ids = components.keys
      @figma_file.components.where.not(node_id: existing_ids).destroy_all

      rows = components.map do |node_id, data|
        validation_warnings = data[:figma_json] ? Figma::ComponentValidator.new(data[:figma_json], is_image: data[:is_image], variant_json_by_id: variant_json_by_id).validate : []

        row = {
          figma_file_id: @figma_file.id,
          node_id: node_id,
          name: data[:name],
          description: data[:description],
          prop_definitions: data[:prop_definitions] || {},
          figma_json: data[:figma_json] || {},
          figma_file_key: @file_key,
          figma_file_name: @file_name,
          slots: data[:slots] || [],
          is_root: data[:is_root] || false,
          is_image: data[:is_image] || false,
          component_key: data[:component_key],
          content_hash: compute_component_hash(data),
          validation_warnings: validation_warnings,
          updated_at: Time.current
        }
        if data[:invalid]
          row[:status] = "error"
          row[:error_message] = data[:invalid_reason]
        else
          row[:status] = "pending"
          row[:error_message] = nil
        end
        row
      end

      Component.upsert_all(rows, unique_by: [:figma_file_id, :node_id]) if rows.any?
    end

    # Content hash for a component set: combines prop_definitions, slots, flags, and all variant figma_jsons.
    # A 16-char hex prefix is plenty for change detection (not security).
    def compute_component_set_hash(data)
      digest = Digest::SHA256.new
      digest.update((data[:prop_definitions] || {}).to_json)
      digest.update((data[:slots] || []).to_json)
      digest.update((data[:is_root] || false).to_s)
      digest.update((data[:is_image] || false).to_s)
      data[:variants].each do |_, vd|
        digest.update(vd[:figma_json].to_json) if vd[:figma_json]
      end
      digest.hexdigest[0..15]
    end

    # Content hash for a standalone component.
    def compute_component_hash(data)
      digest = Digest::SHA256.new
      digest.update((data[:prop_definitions] || {}).to_json)
      digest.update((data[:slots] || []).to_json)
      digest.update((data[:is_root] || false).to_s)
      digest.update((data[:is_image] || false).to_s)
      digest.update(data[:figma_json].to_json) if data[:figma_json]
      digest.hexdigest[0..15]
    end

    # Content hash for a single variant.
    def compute_variant_hash(variant_data)
      digest = Digest::SHA256.new
      digest.update(variant_data[:figma_json].to_json) if variant_data[:figma_json]
      digest.hexdigest[0..15]
    end
  end
end
