module Figma
  # Validates imported Figma components for CSS-reproducibility issues.
  # Returns an array of warning strings. Components with warnings are
  # imported but flagged — excluded from AI generation schema.
  class ComponentValidator
    SKEW_TOLERANCE = 0.01

    def initialize(figma_json, is_image: false, variant_json_by_id: {})
      @json = figma_json
      @is_image = is_image
      @variant_json_by_id = variant_json_by_id
    end

    # Run all validations. Returns array of warning strings.
    def validate
      warnings = []
      return warnings unless @json.is_a?(Hash)

      warnings.concat(check_glass_effects)
      warnings.concat(check_overflow_without_clip)
      warnings.concat(check_skewed_transforms)
      warnings.concat(check_scrolling_content)
      warnings.concat(check_fixed_position_elements)
      warnings.concat(check_instance_style_overrides)
      warnings.concat(check_instance_size_overrides)
      warnings.concat(check_image_convention) if @is_image

      warnings.uniq
    end

    private

    # Glass effects (backdrop blur with saturation) can't be reproduced in CSS
    def check_glass_effects
      nodes = find_nodes(@json) { |node|
        effects = node["effects"] || []
        effects.any? { |e| e["type"] == "GLASS" && e["visible"] != false }
      }
      nodes.map { |n| "Glass effect on \"#{n["name"]}\" — not reproducible in CSS" }
    end

    # Children overflowing parent frame without clipsContent
    def check_overflow_without_clip
      warnings = []
      check_overflow(@json, warnings)
      warnings
    end

    # Skewed/distorted transforms (non-rotation affine transforms)
    def check_skewed_transforms
      nodes = find_nodes(@json) { |node|
        transform = node["relativeTransform"]
        next false unless transform.is_a?(Array) && transform.length >= 2

        a = transform[0][0].to_f
        b = transform[0][1].to_f
        c = transform[1][0].to_f
        d = transform[1][1].to_f

        len1 = Math.sqrt(a * a + c * c)
        len2 = Math.sqrt(b * b + d * d)
        dot = a * b + c * d

        !((len1 - len2).abs < SKEW_TOLERANCE && dot.abs < SKEW_TOLERANCE)
      }
      nodes.map { |n| "Skewed/distorted transform on \"#{n["name"]}\" — only rotation supported in CSS" }
    end

    # Scrolling content (overflowScrolling properties)
    def check_scrolling_content
      nodes = find_nodes(@json) { |node|
        node["overflowDirection"] && node["overflowDirection"] != "NONE"
      }
      nodes.map { |n| "Scrolling content on \"#{n["name"]}\" (#{n["overflowDirection"]}) — scrollable frames render differently in CSS" }
    end

    # Fixed-position elements (layoutPositioning: FIXED or constraints with SCALE)
    def check_fixed_position_elements
      nodes = find_nodes(@json) { |node|
        node["layoutPositioning"] == "FIXED"
      }
      nodes.map { |n| "Fixed-position element \"#{n["name"]}\" — fixed positioning not supported in component rendering" }
    end

    # #image convention: must be a plain frame with fill, no children, no component properties, no corner radius
    def check_image_convention
      warnings = []
      children = @json["children"] || []
      warnings << "#image component has child nodes — must be a plain frame" if children.any?
      warnings << "#image component has corner radius — must be a plain rectangle" if @json["cornerRadius"].to_f > 0
      warnings
    end

    # Detect direct style overrides on instance children (fills/strokes on FRAME/TEXT
    # nodes inside an INSTANCE). These bypass the component's prop API and won't render
    # correctly — the designer should use component props instead.
    OVERRIDE_TYPES = %w[FRAME TEXT GROUP VECTOR BOOLEAN_OPERATION].freeze

    def check_instance_style_overrides
      warnings = []
      find_instance_overrides(@json, warnings)
      warnings
    end

    # Detect instances that have been manually resized (bbox doesn't match the
    # referenced variant). These size overrides bypass the component prop API.
    def check_instance_size_overrides
      warnings = []
      find_resized_instances(@json, warnings)
      warnings
    end

    def find_resized_instances(node, warnings)
      return unless node.is_a?(Hash)
      return if node["visible"] == false

      if node["type"] == "INSTANCE"
        component_id = node["componentId"]
        if component_id
          source_json = @variant_json_by_id[component_id]
          if source_json
            src_bbox = source_json["absoluteBoundingBox"] || {}
            inst_bbox = node["absoluteBoundingBox"] || {}
            sw = src_bbox["width"].to_f
            sh = src_bbox["height"].to_f
            iw = inst_bbox["width"].to_f
            ih = inst_bbox["height"].to_f

            if sw > 0 && sh > 0 && ((sw - iw).abs > 1 || (sh - ih).abs > 1)
              warnings << "Instance \"#{node["name"]}\" is manually resized " \
                "(#{iw.round}x#{ih.round} vs component #{sw.round}x#{sh.round}) — " \
                "size overrides bypass component props"
            end
          end
        end
      end

      (node["children"] || []).each { |child| find_resized_instances(child, warnings) }
    end

    def find_instance_overrides(node, warnings)
      return unless node.is_a?(Hash)
      return if node["visible"] == false

      if node["type"] == "INSTANCE"
        instance_name = node["name"] || "unknown"
        # Look up the source variant to compare against
        source_children = source_variant_children(node)

        # Vector components (SVG icons etc.) use fill overrides as the only way
        # to set color — allow these via currentColor inheritance.
        is_vector = vector_instance?(node, source_children)

        (node["children"] || []).each_with_index do |child, idx|
          next unless OVERRIDE_TYPES.include?(child["type"])
          next if child["visible"] == false

          # Skip if the source variant's matching child has the same fills/strokes
          source_child = source_children && source_children[idx]
          next if source_child && same_fills?(child, source_child)

          # Allow fill color overrides on vector instances — they communicate
          # color via currentColor inheritance, not a design system violation
          next if is_vector && %w[VECTOR BOOLEAN_OPERATION].include?(child["type"])

          has_fill = (child["fills"] || []).any? { |f| f["visible"] != false }
          has_stroke = (child["strokes"] || []).any? { |f| f["visible"] != false }
          next unless has_fill || has_stroke

          parts = []
          parts << "fill" if has_fill
          parts << "stroke" if has_stroke
          warnings << "Instance \"#{instance_name}\" has direct #{parts.join("/")} override on child \"#{child["name"]}\" — use component props instead"
        end
      end

      (node["children"] || []).each { |child| find_instance_overrides(child, warnings) }
    end

    # A vector instance is one whose children are all vector shapes (no FRAME/TEXT).
    # Same concept as vector_frame? in StyleExtractor.
    VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION LINE ELLIPSE RECTANGLE STAR POLYGON].freeze

    def vector_instance?(node, source_children)
      children = source_children || node["children"] || []
      return false if children.empty?
      children.all? { |c| VECTOR_TYPES.include?(c["type"]) }
    end

    def source_variant_children(instance_node)
      component_id = instance_node["componentId"]
      return nil unless component_id
      variant_json = @variant_json_by_id[component_id]
      return nil unless variant_json
      variant_json["children"] || []
    end

    def same_fills?(child, source_child)
      child_fills = (child["fills"] || []).select { |f| f["visible"] != false }
      source_fills = (source_child["fills"] || []).select { |f| f["visible"] != false }
      return true if child_fills.empty? && source_fills.empty?
      return false if child_fills.size != source_fills.size

      # Compare actual fill colors
      child_fills.zip(source_fills).all? do |cf, sf|
        cf["type"] == sf["type"] && fill_color_match?(cf, sf)
      end
    end

    def fill_color_match?(fill_a, fill_b)
      ca = fill_a["color"]
      cb = fill_b["color"]
      return ca == cb if ca && cb
      true # non-SOLID fills — treat as same if type matches
    end

    # Recursive node finder — yields each node, collects those where block returns true
    def find_nodes(node, results = [], &block)
      return results unless node.is_a?(Hash)
      return results if node["visible"] == false

      results << node if yield(node)

      (node["children"] || []).each { |child| find_nodes(child, results, &block) }
      results
    end

    # Check for overflowing children without clipping
    def check_overflow(node, warnings)
      return unless node.is_a?(Hash)
      return if node["visible"] == false

      layout_mode = node["layoutMode"]
      children = node["children"] || []

      if layout_mode && !node["clipsContent"]
        horizontal = layout_mode == "HORIZONTAL"
        axis = horizontal ? "width" : "height"

        bbox = node["absoluteBoundingBox"] || {}
        parent_size = horizontal ? bbox["width"] : bbox["height"]

        if parent_size && parent_size > 0
          flow_children = children.select { |c|
            c["visible"] != false &&
            c["layoutPositioning"] != "ABSOLUTE" &&
            c["layoutPositioning"] != "FIXED"
          }

          if flow_children.size > 1
            padding_start = horizontal ? (node["paddingLeft"] || 0) : (node["paddingTop"] || 0)
            padding_end = horizontal ? (node["paddingRight"] || 0) : (node["paddingBottom"] || 0)
            available = parent_size - padding_start - padding_end

            has_oversized_fixed = flow_children.any? { |c|
              sizing = horizontal ? c["layoutSizingHorizontal"] : c["layoutSizingVertical"]
              next false unless sizing == "FIXED"
              child_bbox = c["absoluteBoundingBox"] || {}
              child_size = (horizontal ? child_bbox["width"] : child_bbox["height"]) || 0
              child_size >= available - 1
            }

            if has_oversized_fixed
              warnings << "Children overflow \"#{node["name"]}\" in #{axis} without clipping — layout may differ in CSS"
            end
          end
        end
      end

      children.each { |child| check_overflow(child, warnings) }
    end
  end
end
