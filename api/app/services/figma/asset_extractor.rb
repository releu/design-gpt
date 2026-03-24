module Figma
  class AssetExtractor
    def initialize(figma_file)
      @figma_file = figma_file
      @figma = Figma::TokenPool.instance.primary_client
    end

    VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
    CONTAINER_TYPES = %w[FRAME GROUP INSTANCE].freeze

    ASSET_CACHE_DIR = Rails.root.join("tmp", "figma_cache", "assets")

    def extract_all
      if Figma::Client.cache_enabled? && restore_from_cache
        return
      end

      puts "[AssetExtractor] Starting asset extraction"

      component_sets_count = extract_for_component_sets
      standalone_count = extract_for_standalone_components
      inline_count = extract_inline_vectors

      puts "[AssetExtractor] Extraction complete: #{component_sets_count} component sets, #{standalone_count} standalone components, #{inline_count} inline vectors"

      dump_to_cache if Figma::Client.cache_enabled?
    end

    private

    def cache_key
      lm = @figma_file.figma_last_modified || "unknown"
      "#{@figma_file.figma_file_key}_#{Digest::SHA256.hexdigest(lm)[0..15]}"
    end

    def dump_to_cache
      FileUtils.mkdir_p(ASSET_CACHE_DIR)
      assets = FigmaAsset.where(component_id: @figma_file.components.pluck(:id))
        .or(FigmaAsset.where(component_set_id: @figma_file.component_sets.pluck(:id)))
        .or(FigmaAsset.where(component_id: nil, component_set_id: nil).where(node_id: all_node_ids))
      data = assets.map { |a| a.attributes.except("id", "created_at", "updated_at") }
      File.write(ASSET_CACHE_DIR.join("#{cache_key}.json"), JSON.generate(data))
      puts "[AssetExtractor] Cached #{data.size} assets to disk"
    rescue => e
      puts "[AssetExtractor] Cache dump failed: #{e.message}"
    end

    def restore_from_cache
      path = ASSET_CACHE_DIR.join("#{cache_key}.json")
      return false unless path.exist?

      data = JSON.parse(File.read(path))
      return false if data.empty?

      puts "[AssetExtractor] Restoring #{data.size} assets from cache..."

      # Build node_id maps for the NEW figma_file's component/component_set IDs
      cs_by_node = @figma_file.component_sets.index_by(&:node_id)
      comp_by_node = @figma_file.components.index_by(&:node_id)

      # We need to remap component_id/component_set_id from old to new
      # The cached data has old IDs, but we can match by node_id
      old_cs_ids = data.filter_map { |d| d["component_set_id"] }.uniq
      old_comp_ids = data.filter_map { |d| d["component_id"] }.uniq

      old_cs_node_map = ComponentSet.where(id: old_cs_ids).pluck(:id, :node_id).to_h
      old_comp_node_map = Component.where(id: old_comp_ids).pluck(:id, :node_id).to_h

      records = data.map do |attrs|
        new_attrs = attrs.dup
        if attrs["component_set_id"]
          node_id = old_cs_node_map[attrs["component_set_id"]]
          new_cs = node_id ? cs_by_node[node_id] : nil
          new_attrs["component_set_id"] = new_cs&.id
        end
        if attrs["component_id"]
          node_id = old_comp_node_map[attrs["component_id"]]
          new_comp = node_id ? comp_by_node[node_id] : nil
          new_attrs["component_id"] = new_comp&.id
        end
        new_attrs
      end

      # Bulk insert
      FigmaAsset.insert_all(records)
      puts "[AssetExtractor] Restored #{records.size} assets from cache"
      true
    rescue => e
      puts "[AssetExtractor] Cache restore failed: #{e.message}, falling back to extraction"
      false
    end

    def all_node_ids
      @figma_file.component_sets.joins(:variants).pluck("component_variants.node_id") +
        @figma_file.components.pluck(:node_id)
    end

    public

    def extract_for_component_sets
      component_sets = @figma_file.component_sets
      total_count = component_sets.count
      vector_sets = component_sets.select(&:vector?)

      puts "[AssetExtractor] Component sets: #{vector_sets.size} vectors out of #{total_count} total"

      vector_sets.group_by(&:figma_file_key).each do |file_key, sets|
        puts "[AssetExtractor]   Processing #{sets.size} component sets from #{sets.first&.figma_file_name}"
        fetch_and_save_component_set_svgs(file_key, sets)
      end

      vector_sets.size
    end

    def extract_for_standalone_components
      components = @figma_file.components
      total_count = components.count
      vector_components = components.select(&:vector?)

      puts "[AssetExtractor] Standalone components: #{vector_components.size} vectors out of #{total_count} total"

      vector_components.group_by(&:figma_file_key).each do |file_key, comps|
        puts "[AssetExtractor]   Processing #{comps.size} standalone components from #{comps.first&.figma_file_name}"
        fetch_and_save_component_svgs(file_key, comps)
      end

      vector_components.size
    end

    def extract_for_component_set(component_set)
      fetch_and_save_component_set_svgs(component_set.figma_file_key, [component_set])
    end

    def extract_for_component(component)
      fetch_and_save_component_svgs(component.figma_file_key, [component])
    end

    def extract_inline_vectors
      puts "[AssetExtractor] Scanning for inline vector frames..."

      inline_vectors_by_file = {}
      @inline_images_by_file = {}  # nodes with IMAGE fills → export as PNG
      # Track componentId -> [node_ids] for INSTANCE deduplication
      @instance_component_groups = {}
      @image_instance_component_groups = {}

      @figma_file.component_sets.includes(:variants).each do |cs|
        cs.variants.each do |variant|
          next unless variant.figma_json.present?
          find_inline_vectors(variant.figma_json, cs.figma_file_key, inline_vectors_by_file)
        end
      end

      @figma_file.components.each do |comp|
        next unless comp.figma_json.present?
        find_inline_vectors(comp.figma_json, comp.figma_file_key, inline_vectors_by_file)
      end

      total_count = inline_vectors_by_file.values.sum(&:size)

      # Deduplicate: for INSTANCE nodes sharing a componentId, export only one
      representatives = {}  # node_id (to export) -> [all node_ids sharing same componentId]
      instance_node_ids = @instance_component_groups.values.flatten.to_set

      inline_vectors_by_file.each do |file_key, node_ids|
        deduped = []
        node_ids.each do |nid|
          if instance_node_ids.include?(nid)
            # Find which componentId group this belongs to
            group = @instance_component_groups.find { |_, ids| ids.include?(nid) }
            next unless group
            comp_id, all_ids = group
            representative = all_ids.first
            unless representatives.key?(representative)
              representatives[representative] = all_ids
              deduped << representative
            end
          else
            deduped << nid
          end
        end
        inline_vectors_by_file[file_key] = deduped
      end

      deduped_count = inline_vectors_by_file.values.sum(&:size)
      puts "[AssetExtractor] Found #{total_count} inline vector frames (#{deduped_count} unique after dedup)"

      saved_count = 0
      inline_vectors_by_file.each do |file_key, node_ids|
        puts "[AssetExtractor]   Processing #{node_ids.size} inline vectors from file #{file_key}"
        saved_count += fetch_and_save_inline_svgs(file_key, node_ids, representatives)
      end

      puts "[AssetExtractor] Saved #{saved_count} inline SVGs"

      # Export raster nodes as PNG
      image_total = @inline_images_by_file.values.sum(&:size)
      if image_total > 0
        # Deduplicate by componentId
        image_representatives = {}
        image_instance_ids = @image_instance_component_groups.values.flatten.to_set

        @inline_images_by_file.each do |file_key, node_ids|
          deduped = []
          node_ids.each do |nid|
            if image_instance_ids.include?(nid)
              group = @image_instance_component_groups.find { |_, ids| ids.include?(nid) }
              next unless group
              _comp_id, all_ids = group
              representative = all_ids.first
              unless image_representatives.key?(representative)
                image_representatives[representative] = all_ids
                deduped << representative
              end
            else
              deduped << nid
            end
          end
          @inline_images_by_file[file_key] = deduped
        end

        deduped_image_count = @inline_images_by_file.values.sum(&:size)
        puts "[AssetExtractor] Found #{image_total} inline images (#{deduped_image_count} unique after dedup)"

        image_saved = 0
        @inline_images_by_file.each do |file_key, node_ids|
          puts "[AssetExtractor]   Processing #{node_ids.size} inline images from file #{file_key}"
          image_saved += fetch_and_save_inline_pngs(file_key, node_ids, image_representatives)
        end
        puts "[AssetExtractor] Saved #{image_saved} inline PNGs"
      end

      total_count + image_total
    end

    private

    def fetch_and_save_component_set_svgs(file_key, component_sets)
      return if component_sets.empty?

      variant_to_set = {}
      component_sets.each do |cs|
        variant = cs.default_variant
        next unless variant
        variant_to_set[variant.node_id] = cs
      end

      return if variant_to_set.empty?

      mutex = Mutex.new

      variant_to_set.keys.each_slice(100) do |batch_node_ids|
        begin
          response = Figma::TokenPool.instance.next_client.export_svg(file_key, batch_node_ids)
          images = response["images"] || {}

          threads = []
          batch_node_ids.each do |variant_node_id|
            component_set = variant_to_set[variant_node_id]
            svg_url = images[variant_node_id]
            next if svg_url.blank?

            threads << Thread.new(component_set, svg_url) do |cs, url|
              begin
                svg_content = Figma::TokenPool.instance.next_client.fetch_svg_content(url)
                mutex.synchronize do
                  save_component_set_asset(cs, svg_content)
                  puts "[AssetExtractor] Saved SVG for component set: #{cs.name}"
                end
              rescue => e
                puts "[AssetExtractor] Failed to fetch SVG for #{cs.name}: #{e.message}"
              end
            end

            if threads.size >= 10
              threads.each(&:join)
              threads.clear
            end
          end

          threads.each(&:join)
        rescue => e
          puts "[AssetExtractor] Batch request failed: #{e.message}"
        end
      end
    end

    def fetch_and_save_component_svgs(file_key, components)
      return if components.empty?

      mutex = Mutex.new

      components.each_slice(100) do |batch|
        node_ids = batch.map(&:node_id)

        begin
          response = Figma::TokenPool.instance.next_client.export_svg(file_key, node_ids)
          images = response["images"] || {}

          threads = []
          batch.each do |component|
            svg_url = images[component.node_id]
            next if svg_url.blank?

            threads << Thread.new(component, svg_url) do |comp, url|
              begin
                svg_content = Figma::TokenPool.instance.next_client.fetch_svg_content(url)
                mutex.synchronize do
                  save_component_asset(comp, svg_content)
                  puts "[AssetExtractor] Saved SVG for component: #{comp.name}"
                end
              rescue => e
                puts "[AssetExtractor] Failed to fetch SVG for #{comp.name}: #{e.message}"
              end
            end

            if threads.size >= 10
              threads.each(&:join)
              threads.clear
            end
          end

          threads.each(&:join)
        rescue => e
          puts "[AssetExtractor] Batch request failed: #{e.message}"
        end
      end
    end

    def save_component_set_asset(component_set, svg_content)
      asset = component_set.figma_assets.find_or_initialize_by(node_id: component_set.node_id)
      asset.update!(
        name: component_set.name,
        asset_type: "svg",
        content: svg_content
      )
    end

    def save_component_asset(component, svg_content)
      asset = component.figma_assets.find_or_initialize_by(node_id: component.node_id)
      asset.update!(
        name: component.name,
        asset_type: "svg",
        content: svg_content
      )
    end

    def find_inline_vectors(node, file_key, result)
      return unless node.is_a?(Hash)

      # INSTANCE nodes are normally rendered as component references by
      # ReactFactory.  However, unresolved instances (e.g. icons from an
      # external library) fall back to inline rendering — if they look like
      # vector frames, export them as SVGs so the factory can inline them.
      if node["type"] == "INSTANCE"
        if node["id"]
          if has_image_fill?(node)
            # Raster content — export as PNG, not SVG
            @inline_images_by_file[file_key] ||= []
            @inline_images_by_file[file_key] << node["id"] unless @inline_images_by_file[file_key].include?(node["id"])
            comp_id = node["componentId"]
            if comp_id
              @image_instance_component_groups[comp_id] ||= []
              @image_instance_component_groups[comp_id] << node["id"] unless @image_instance_component_groups[comp_id].include?(node["id"])
            end
          elsif vector_frame?(node)
            # Skip export for INSTANCE nodes that resolve to known components —
            # ReactFactory will render <ComponentName /> instead of inline SVG
            comp_id = node["componentId"]
            unless comp_id && resolvable_instance?(comp_id)
              result[file_key] ||= []
              result[file_key] << node["id"] unless result[file_key].include?(node["id"])
              if comp_id && @instance_component_groups
                @instance_component_groups[comp_id] ||= []
                @instance_component_groups[comp_id] << node["id"] unless @instance_component_groups[comp_id].include?(node["id"])
              end
            end
          end
        end
        return # never recurse into instance children
      end

      node_id = node["id"]

      # Raster content — export as PNG
      if has_image_fill?(node)
        if node_id
          @inline_images_by_file[file_key] ||= []
          @inline_images_by_file[file_key] << node_id unless @inline_images_by_file[file_key].include?(node_id)
        end
        return
      end

      # Only export composed vector frames (icons, logos) as SVG.
      # Bare vector nodes (individual paths, shapes) inside regular frames
      # are single strokes that render fine with CSS fallback.
      if vector_frame?(node)
        if node_id
          result[file_key] ||= []
          result[file_key] << node_id unless result[file_key].include?(node_id)
        end
        return
      end

      (node["children"] || []).each do |child|
        find_inline_vectors(child, file_key, result)
      end
    end

    COMPLEX_VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION STAR POLYGON].freeze
    TRIVIAL_VECTOR_TYPES = %w[RECTANGLE ELLIPSE LINE].freeze

    def vector_frame?(node)
      return false unless node.is_a?(Hash)
      return false unless CONTAINER_TYPES.include?(node["type"])

      children = node["children"] || []
      return false if children.empty?
      return false unless children.all? { |child| vector_only?(child) }

      # Skip trivial shapes (single rectangle, ellipse, line) — CSS handles these fine.
      # Only export frames that contain complex paths (VECTOR, BOOLEAN_OPERATION, STAR, POLYGON).
      has_complex_vector?(node)
    end

    def has_complex_vector?(node)
      return false unless node.is_a?(Hash)
      return true if COMPLEX_VECTOR_TYPES.include?(node["type"])

      (node["children"] || []).any? { |child| has_complex_vector?(child) }
    end

    def vector_only?(node)
      return false unless node.is_a?(Hash)
      return true if VECTOR_TYPES.include?(node["type"])

      if CONTAINER_TYPES.include?(node["type"])
        children = node["children"] || []
        return false if children.empty?
        return children.all? { |child| vector_only?(child) }
      end

      false
    end

    def fetch_and_save_inline_svgs(file_key, node_ids, representatives = {})
      return 0 if node_ids.empty?

      saved_count = 0
      total_batches = (node_ids.size / 100.0).ceil
      mutex = Mutex.new

      node_ids.each_slice(100).with_index do |batch, batch_idx|
        puts "[AssetExtractor]     Batch #{batch_idx + 1}/#{total_batches} (#{saved_count} saved so far)"

        begin
          # Rotate tokens across batches for rate limit distribution
          export_client = Figma::TokenPool.instance.next_client
          response = export_client.export_svg(file_key, batch)
          images = response["images"] || {}

          # Fetch SVG content in parallel (up to 10 threads)
          threads = []
          batch.each do |node_id|
            svg_url = images[node_id]
            next if svg_url.blank?

            threads << Thread.new(node_id, svg_url) do |nid, url|
              begin
                svg_content = Figma::TokenPool.instance.next_client.fetch_svg_content(url)
                mutex.synchronize do
                  # Save for the representative node
                  save_inline_svg(nid, svg_content)
                  saved_count += 1
                  # Save for all duplicate node_ids sharing the same componentId
                  if representatives[nid]
                    representatives[nid].each do |dup_nid|
                      next if dup_nid == nid
                      save_inline_svg(dup_nid, svg_content)
                      saved_count += 1
                    end
                  end
                end
              rescue => e
                puts "[AssetExtractor] Failed to fetch inline SVG for #{nid}: #{e.message}"
              end
            end

            # Limit concurrency to 10 parallel fetches
            if threads.size >= 10
              threads.each(&:join)
              threads.clear
            end
          end

          threads.each(&:join)
        rescue => e
          puts "[AssetExtractor] Batch request failed: #{e.message}"
        end
      end

      saved_count
    end

    # Check if a componentId resolves to a known component in the same design system
    def resolvable_instance?(component_id)
      return false unless @figma_file.design_system

      @resolvable_cache ||= begin
        ids = Set.new
        @figma_file.design_system.current_figma_files.each do |ff|
          ff.component_sets.pluck(:node_id).each { |nid| ids << nid }
          ff.components.pluck(:node_id).each { |nid| ids << nid }
          ComponentVariant.where(component_set_id: ff.component_set_ids).pluck(:node_id).each { |nid| ids << nid }
        end
        # Also check component_key_map for cross-file resolution
        key_map = @figma_file.component_key_map || {}
        variant_keys = Set.new
        @figma_file.design_system.current_figma_files.each do |ff|
          ComponentVariant.where(component_set_id: ff.component_set_ids).where.not(component_key: nil).pluck(:component_key).each { |k| variant_keys << k }
        end
        { ids: ids, key_map: key_map, variant_keys: variant_keys }
      end

      return true if @resolvable_cache[:ids].include?(component_id)

      comp_key = @resolvable_cache[:key_map][component_id]
      return true if comp_key && @resolvable_cache[:variant_keys].include?(comp_key)

      false
    end

    def has_image_fill?(node)
      return false unless node.is_a?(Hash)
      fills = node["fills"] || node["background"] || []
      fills.any? { |f| f["type"] == "IMAGE" }
    end

    def fetch_and_save_inline_pngs(file_key, node_ids, representatives = {})
      return 0 if node_ids.empty?

      saved_count = 0
      total_batches = (node_ids.size / 100.0).ceil
      mutex = Mutex.new

      node_ids.each_slice(100).with_index do |batch, batch_idx|
        puts "[AssetExtractor]     PNG Batch #{batch_idx + 1}/#{total_batches} (#{saved_count} saved so far)"

        begin
          export_client = Figma::TokenPool.instance.next_client
          response = export_client.export_png(file_key, batch, scale: 2)
          images = response["images"] || {}

          threads = []
          batch.each do |node_id|
            png_url = images[node_id]
            next if png_url.blank?

            threads << Thread.new(node_id, png_url) do |nid, url|
              begin
                png_content = Figma::TokenPool.instance.next_client.fetch_binary_content(url)
                mutex.synchronize do
                  save_inline_png(nid, png_content)
                  saved_count += 1
                  if representatives[nid]
                    representatives[nid].each do |dup_nid|
                      next if dup_nid == nid
                      save_inline_png(dup_nid, png_content)
                      saved_count += 1
                    end
                  end
                end
              rescue => e
                puts "[AssetExtractor] Failed to fetch inline PNG for #{nid}: #{e.message}"
              end
            end

            if threads.size >= 10
              threads.each(&:join)
              threads.clear
            end
          end

          threads.each(&:join)
        rescue => e
          puts "[AssetExtractor] PNG batch request failed: #{e.message}"
        end
      end

      saved_count
    end

    def save_inline_png(node_id, png_content)
      asset = FigmaAsset.find_or_initialize_by(node_id: node_id, component_id: nil, component_set_id: nil)
      asset.update!(
        name: "inline_#{node_id}",
        asset_type: "png",
        content: Base64.strict_encode64(png_content)
      )
    end

    def save_inline_svg(node_id, svg_content)
      asset = FigmaAsset.find_or_initialize_by(node_id: node_id, component_id: nil, component_set_id: nil)
      asset.update!(
        name: "inline_#{node_id}",
        asset_type: "svg",
        content: svg_content
      )
    end
  end
end
