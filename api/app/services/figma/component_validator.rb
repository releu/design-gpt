module Figma
  # Validates imported Figma components for CSS-reproducibility issues.
  # Returns an array of warning strings. Components with warnings are
  # imported but flagged — excluded from AI generation schema.
  class ComponentValidator
    SKEW_TOLERANCE = 0.01

    def initialize(figma_json)
      @json = figma_json
    end

    # Run all validations. Returns array of warning strings.
    def initialize(figma_json, is_image: false)
      @json = figma_json
      @is_image = is_image
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
