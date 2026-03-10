module Figma
  class AssetExtractor
    def initialize(figma_file)
      @figma_file = figma_file
      @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    end

    VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
    CONTAINER_TYPES = %w[FRAME GROUP].freeze

    def extract_all
      puts "[AssetExtractor] Starting asset extraction"

      component_sets_count = extract_for_component_sets
      standalone_count = extract_for_standalone_components
      inline_count = extract_inline_vectors

      puts "[AssetExtractor] Extraction complete: #{component_sets_count} component sets, #{standalone_count} standalone components, #{inline_count} inline vectors"
    end

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
      puts "[AssetExtractor] Found #{total_count} inline vector frames"

      saved_count = 0
      inline_vectors_by_file.each do |file_key, node_ids|
        puts "[AssetExtractor]   Processing #{node_ids.size} inline vectors from file #{file_key}"
        saved_count += fetch_and_save_inline_svgs(file_key, node_ids)
      end

      puts "[AssetExtractor] Saved #{saved_count} inline SVGs"
      total_count
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
          response = @figma.export_svg(file_key, batch_node_ids)
          images = response["images"] || {}

          threads = []
          batch_node_ids.each do |variant_node_id|
            component_set = variant_to_set[variant_node_id]
            svg_url = images[variant_node_id]
            next if svg_url.blank?

            threads << Thread.new(component_set, svg_url) do |cs, url|
              begin
                svg_content = Figma::Client.new(ENV["FIGMA_TOKEN"]).fetch_svg_content(url)
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
          response = @figma.export_svg(file_key, node_ids)
          images = response["images"] || {}

          threads = []
          batch.each do |component|
            svg_url = images[component.node_id]
            next if svg_url.blank?

            threads << Thread.new(component, svg_url) do |comp, url|
              begin
                svg_content = Figma::Client.new(ENV["FIGMA_TOKEN"]).fetch_svg_content(url)
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

      if vector_frame?(node)
        node_id = node["id"]
        if node_id && !node_id.start_with?("I")
          result[file_key] ||= []
          result[file_key] << node_id unless result[file_key].include?(node_id)
        end
        return
      end

      (node["children"] || []).each do |child|
        find_inline_vectors(child, file_key, result)
      end
    end

    def vector_frame?(node)
      return false unless node.is_a?(Hash)
      return false unless CONTAINER_TYPES.include?(node["type"])

      children = node["children"] || []
      return false if children.empty?

      children.all? { |child| vector_only?(child) }
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

    def fetch_and_save_inline_svgs(file_key, node_ids)
      return 0 if node_ids.empty?

      saved_count = 0
      total_batches = (node_ids.size / 100.0).ceil
      mutex = Mutex.new

      node_ids.each_slice(100).with_index do |batch, batch_idx|
        puts "[AssetExtractor]     Batch #{batch_idx + 1}/#{total_batches} (#{saved_count} saved so far)"

        begin
          response = @figma.export_svg(file_key, batch)
          images = response["images"] || {}

          # Fetch SVG content in parallel (up to 10 threads)
          threads = []
          batch.each do |node_id|
            svg_url = images[node_id]
            next if svg_url.blank?

            threads << Thread.new(node_id, svg_url) do |nid, url|
              begin
                svg_content = Figma::Client.new(ENV["FIGMA_TOKEN"]).fetch_svg_content(url)
                mutex.synchronize do
                  save_inline_svg(nid, svg_content)
                  saved_count += 1
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
