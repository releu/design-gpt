# Shared module for extracting CSS styles from Figma JSON
# Used by both Figma::ReactFactory (design system components) and Figma::HtmlConverter (1:1 conversion)
module Figma
  module StyleExtractor
    VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
    CONTAINER_TYPES = %w[FRAME GROUP COMPONENT COMPONENT_SET INSTANCE SECTION].freeze

    # ============================================
    # Style Extraction
    # ============================================

    def extract_frame_styles(node, is_root = false)
      styles = {}

      # Dimensions
      bbox = node["absoluteBoundingBox"] || {}
      size = node["size"] || {}

      width = size["x"] || bbox["width"]
      height = size["y"] || bbox["height"]

      # Handle sizing modes for auto-layout
      layout_mode = node["layoutMode"]

      if layout_mode
        styles["display"] = "flex"
        styles["flex-direction"] = layout_mode == "HORIZONTAL" ? "row" : "column"

        primary_align = node["primaryAxisAlignItems"] || "MIN"
        counter_align = node["counterAxisAlignItems"] || "MIN"

        styles["justify-content"] = figma_align_to_css(primary_align)
        styles["align-items"] = figma_align_to_css(counter_align)

        item_spacing = node["itemSpacing"]
        styles["gap"] = "#{item_spacing}px" if item_spacing && item_spacing > 0

        counter_spacing = node["counterAxisSpacing"]
        if counter_spacing && counter_spacing > 0 && node["layoutWrap"] == "WRAP"
          styles["row-gap"] = "#{counter_spacing}px"
        end

        styles["flex-wrap"] = "wrap" if node["layoutWrap"] == "WRAP"
      end

      if node["layoutPositioning"] == "ABSOLUTE"
        styles["position"] = "absolute"
      else
        styles["position"] = "relative"
      end

      # Sizing mode
      primary_sizing = node["primaryAxisSizingMode"]
      counter_sizing = node["counterAxisSizingMode"]

      if layout_mode == "HORIZONTAL"
        if primary_sizing == "FIXED"
          styles["width"] = "#{width}px"
        elsif primary_sizing == "HUG"
          styles["width"] = "fit-content"
        end

        if counter_sizing == "FIXED"
          styles["height"] = "#{height}px"
        elsif counter_sizing == "HUG"
          styles["height"] = "fit-content"
        end
      elsif layout_mode == "VERTICAL"
        if counter_sizing == "FIXED"
          styles["width"] = "#{width}px"
        elsif counter_sizing == "HUG"
          styles["width"] = "fit-content"
        end

        if primary_sizing == "FIXED"
          styles["height"] = "#{height}px"
        elsif primary_sizing == "HUG"
          styles["height"] = "fit-content"
        end
      else
        styles["width"] = "#{width}px" if width
        styles["height"] = "#{height}px" if height
      end

      # Min/Max sizing
      add_min_max_size(styles, node)

      # Layout grow
      if node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-grow"] = node["layoutGrow"].to_s
        styles["flex-basis"] = "0"
      end

      layout_sizing_h = node["layoutSizingHorizontal"]
      layout_sizing_v = node["layoutSizingVertical"]

      own_width_fixed = (layout_mode == "HORIZONTAL" && primary_sizing == "FIXED") ||
                        (layout_mode == "VERTICAL" && counter_sizing == "FIXED")
      own_height_fixed = (layout_mode == "VERTICAL" && primary_sizing == "FIXED") ||
                         (layout_mode == "HORIZONTAL" && counter_sizing == "FIXED")

      if layout_sizing_h == "FILL"
        styles["width"] = "100%"
      elsif layout_sizing_h == "HUG" && !own_width_fixed
        styles["width"] = "fit-content"
      elsif layout_sizing_h == "FIXED"
        styles["width"] = "#{width}px"
      end

      if layout_sizing_v == "FILL"
        styles["height"] = "100%"
      elsif layout_sizing_v == "HUG" && !own_height_fixed
        styles["height"] = "fit-content"
      elsif layout_sizing_v == "FIXED"
        styles["height"] = "#{height}px"
      end

      if node["layoutAlign"] == "STRETCH"
        styles["align-self"] = "stretch"
      end

      unless node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-shrink"] = "0"
      end

      add_padding(styles, node)
      add_fills(styles, node["fills"])

      if node["type"] == "COMPONENT" && !styles["background"]
        fills = node["fills"] || []
        visible_fills = fills.select { |f| f["visible"] != false }
        if visible_fills.empty?
          styles["background"] = "#fff"
        end
      end

      add_strokes(styles, node)
      add_border_radius(styles, node)
      add_effects(styles, node["effects"])

      case node["overflowDirection"]
      when "HORIZONTAL_SCROLLING"
        styles["overflow-x"] = "auto"
        styles["overflow-y"] = "hidden"
        # fit-content defeats scrolling — use bbox width instead
        styles["width"] = "#{width}px" if styles["width"] == "fit-content"
      when "VERTICAL_SCROLLING"
        styles["overflow-x"] = "hidden"
        styles["overflow-y"] = "auto"
        # fit-content defeats scrolling — use bbox height instead
        styles["height"] = "#{height}px" if styles["height"] == "fit-content"
      when "HORIZONTAL_AND_VERTICAL_SCROLLING"
        styles["overflow"] = "auto"
        styles["width"] = "#{width}px" if styles["width"] == "fit-content"
        styles["height"] = "#{height}px" if styles["height"] == "fit-content"
      else
        styles["overflow"] = "hidden" if node["clipsContent"]
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      styles["display"] = "none" if node["visible"] == false

      styles["box-sizing"] = "border-box"

      styles
    end

    def extract_text_styles(node)
      styles = {}

      style = node["style"] || {}

      styles["font-family"] = "\"#{style["fontFamily"]}\", sans-serif" if style["fontFamily"]
      styles["font-size"] = "#{style["fontSize"]}px" if style["fontSize"]
      styles["font-weight"] = style["fontWeight"].to_s if style["fontWeight"]
      styles["font-style"] = "italic" if style["italic"]

      if style["lineHeightPx"]
        styles["line-height"] = "#{style["lineHeightPx"]}px"
      elsif style["lineHeightPercentFontSize"]
        styles["line-height"] = "#{(style["lineHeightPercentFontSize"] / 100.0).round(2)}"
      elsif style["lineHeightUnit"] == "AUTO"
        styles["line-height"] = "normal"
      end

      if style["letterSpacing"] && style["letterSpacing"] != 0
        styles["letter-spacing"] = "#{style["letterSpacing"]}px"
      end

      text_align = style["textAlignHorizontal"]
      styles["text-align"] = text_align.downcase if text_align

      text_align_vertical = style["textAlignVertical"]
      if text_align_vertical && text_align_vertical != "TOP"
        styles["display"] = "flex"
        styles["align-items"] = case text_align_vertical
                                when "CENTER" then "center"
                                when "BOTTOM" then "flex-end"
                                else "flex-start"
                                end
      end

      if style["textDecoration"] == "UNDERLINE"
        styles["text-decoration"] = "underline"
      elsif style["textDecoration"] == "STRIKETHROUGH"
        styles["text-decoration"] = "line-through"
      end

      case style["textCase"]
      when "UPPER"
        styles["text-transform"] = "uppercase"
      when "LOWER"
        styles["text-transform"] = "lowercase"
      when "TITLE"
        styles["text-transform"] = "capitalize"
      when "SMALL_CAPS"
        styles["font-variant"] = "small-caps"
      end

      fills = node["fills"] || []
      visible_fill = fills.find { |f| f["visible"] != false && f["type"] == "SOLID" }
      if visible_fill && visible_fill["color"]
        styles["color"] = figma_color_to_css(visible_fill["color"], visible_fill["opacity"])
      end

      if node["textTruncation"] == "ENDING"
        max_lines = node["maxLines"]
        styles["overflow"] = "hidden"
        styles["text-overflow"] = "ellipsis"

        if max_lines && max_lines > 1
          styles["display"] = "-webkit-box"
          styles["-webkit-line-clamp"] = max_lines.to_s
          styles["-webkit-box-orient"] = "vertical"
        else
          styles["white-space"] = "nowrap"
        end
      end

      text_auto_resize = node.dig("style", "textAutoResize")
      if text_auto_resize == "WIDTH_AND_HEIGHT"
        styles["white-space"] = "nowrap"
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      layout_sizing_h = node["layoutSizingHorizontal"]
      layout_sizing_v = node["layoutSizingVertical"]

      if layout_sizing_h == "FILL"
        styles["width"] = "100%"
      elsif layout_sizing_h == "FIXED"
        bbox = node["absoluteBoundingBox"] || {}
        styles["width"] = "#{bbox["width"]}px" if bbox["width"]
      end

      if layout_sizing_v == "FILL"
        styles["height"] = "100%"
      elsif layout_sizing_v == "FIXED"
        bbox = node["absoluteBoundingBox"] || {}
        styles["height"] = "#{bbox["height"]}px" if bbox["height"]
      end

      styles["flex-shrink"] = "0"
      if node["layoutPositioning"] == "ABSOLUTE"
        styles["position"] = "absolute"
      else
        styles["position"] = "relative"
      end
      styles["margin"] = "0"
      styles["word-wrap"] = "break-word"
      styles["overflow-wrap"] = "break-word"

      styles
    end

    def extract_shape_styles(node)
      styles = {}

      bbox = node["absoluteBoundingBox"] || {}
      size = node["size"] || {}

      width = size["x"] || bbox["width"]
      height = size["y"] || bbox["height"]

      layout_sizing_h = node["layoutSizingHorizontal"]
      layout_sizing_v = node["layoutSizingVertical"]

      if layout_sizing_h == "FILL"
        styles["width"] = "100%"
      else
        styles["width"] = "#{width}px" if width
      end

      if layout_sizing_v == "FILL"
        styles["height"] = "100%"
      else
        styles["height"] = "#{height}px" if height
      end

      if node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-grow"] = node["layoutGrow"].to_s
      end

      unless node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-shrink"] = "0"
      end

      styles["border-radius"] = "50%" if node["type"] == "ELLIPSE"

      if node["type"] == "LINE"
        styles["height"] = "0"
        styles["border-top"] = "1px solid"
      end

      add_fills(styles, node["fills"])
      add_strokes(styles, node)
      add_border_radius(styles, node) unless node["type"] == "ELLIPSE"
      add_effects(styles, node["effects"])

      if node["rotation"] && node["rotation"] != 0
        styles["transform"] = "rotate(#{-node["rotation"]}deg)"
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      if node["layoutPositioning"] == "ABSOLUTE"
        styles["position"] = "absolute"
      else
        styles["position"] = "relative"
      end
      styles["box-sizing"] = "border-box"
      styles["flex-shrink"] = "0"

      styles
    end

    def extract_absolute_position(node, parent)
      styles = {}

      node_bbox = node["absoluteBoundingBox"] || {}
      parent_bbox = parent["absoluteBoundingBox"] || {}

      return styles if node_bbox.empty? || parent_bbox.empty?

      constraints = node["constraints"] || {}
      h_constraint = constraints["horizontal"] || "LEFT"
      v_constraint = constraints["vertical"] || "TOP"

      node_x = node_bbox["x"] || 0
      node_y = node_bbox["y"] || 0
      node_w = node_bbox["width"] || 0
      node_h = node_bbox["height"] || 0
      parent_x = parent_bbox["x"] || 0
      parent_y = parent_bbox["y"] || 0
      parent_w = parent_bbox["width"] || 0
      parent_h = parent_bbox["height"] || 0

      case h_constraint
      when "RIGHT"
        styles["right"] = "#{(parent_x + parent_w - node_x - node_w).round}px"
      when "LEFT_RIGHT"
        styles["left"] = "#{(node_x - parent_x).round}px"
        styles["right"] = "#{(parent_x + parent_w - node_x - node_w).round}px"
      when "CENTER"
        left = node_x - parent_x
        styles["left"] = "#{left.round}px"
      else # LEFT
        styles["left"] = "#{(node_x - parent_x).round}px"
      end

      case v_constraint
      when "BOTTOM"
        styles["bottom"] = "#{(parent_y + parent_h - node_y - node_h).round}px"
      when "TOP_BOTTOM"
        styles["top"] = "#{(node_y - parent_y).round}px"
        styles["bottom"] = "#{(parent_y + parent_h - node_y - node_h).round}px"
      when "CENTER"
        top = node_y - parent_y
        styles["top"] = "#{top.round}px"
      else # TOP
        styles["top"] = "#{(node_y - parent_y).round}px"
      end

      styles
    end

    # ============================================
    # Style Helpers
    # ============================================

    def add_min_max_size(styles, node)
      styles["min-width"] = "#{node["minWidth"]}px" if node["minWidth"]&.positive?
      styles["max-width"] = "#{node["maxWidth"]}px" if node["maxWidth"]&.positive?
      styles["min-height"] = "#{node["minHeight"]}px" if node["minHeight"]&.positive?
      styles["max-height"] = "#{node["maxHeight"]}px" if node["maxHeight"]&.positive?
    end

    def add_padding(styles, node)
      top = node["paddingTop"] || 0
      right = node["paddingRight"] || 0
      bottom = node["paddingBottom"] || 0
      left = node["paddingLeft"] || 0

      if top > 0 || right > 0 || bottom > 0 || left > 0
        if top == right && right == bottom && bottom == left
          styles["padding"] = "#{top}px"
        elsif top == bottom && left == right
          styles["padding"] = "#{top}px #{right}px"
        else
          styles["padding"] = "#{top}px #{right}px #{bottom}px #{left}px"
        end
      end
    end

    def add_fills(styles, fills)
      return unless fills.is_a?(Array)

      visible_fills = fills.select { |f| f["visible"] != false }
      return if visible_fills.empty?

      has_multiple_fills = visible_fills.size > 1

      backgrounds = visible_fills.reverse.map.with_index do |fill, idx|
        is_bottom_layer = (idx == visible_fills.size - 1)

        case fill["type"]
        when "SOLID"
          color = figma_color_to_css(fill["color"], fill["opacity"])
          if has_multiple_fills && !is_bottom_layer
            "linear-gradient(#{color}, #{color})"
          else
            color
          end
        when "GRADIENT_LINEAR"
          generate_linear_gradient(fill, fill["opacity"])
        when "GRADIENT_RADIAL"
          generate_radial_gradient(fill, fill["opacity"])
        when "GRADIENT_ANGULAR"
          generate_angular_gradient(fill, fill["opacity"])
        when "GRADIENT_DIAMOND"
          generate_radial_gradient(fill, fill["opacity"])
        when "IMAGE"
          handle_image_fill(fill) if respond_to?(:handle_image_fill, true)
        end
      end.compact

      if backgrounds.size == 1
        styles["background"] = backgrounds.first
      elsif backgrounds.size > 1
        styles["background"] = backgrounds.join(", ")
      end
    end

    def add_strokes(styles, node)
      strokes = node["strokes"]
      return unless strokes.is_a?(Array)

      visible_strokes = strokes.select { |s| s["visible"] != false }
      return if visible_strokes.empty?

      stroke = visible_strokes.first
      weight = node["strokeWeight"] || 1

      color = if stroke["type"] == "SOLID" && stroke["color"]
        figma_color_to_css(stroke["color"], stroke["opacity"])
      else
        "#000000"
      end

      stroke_align = node["strokeAlign"] || "CENTER"
      existing_shadow = styles["box-shadow"]

      case stroke_align
      when "INSIDE"
        shadow = "inset 0 0 0 #{weight}px #{color}"
        styles["box-shadow"] = existing_shadow ? "#{existing_shadow}, #{shadow}" : shadow
      when "OUTSIDE"
        shadow = "0 0 0 #{weight}px #{color}"
        styles["box-shadow"] = existing_shadow ? "#{existing_shadow}, #{shadow}" : shadow
      else
        styles["border"] = "#{weight}px solid #{color}"
      end

      if node["individualStrokeWeights"] && stroke_align == "CENTER"
        weights = node["individualStrokeWeights"]
        styles.delete("border")
        styles["border-top"] = "#{weights["top"]}px solid #{color}" if weights["top"]&.positive?
        styles["border-right"] = "#{weights["right"]}px solid #{color}" if weights["right"]&.positive?
        styles["border-bottom"] = "#{weights["bottom"]}px solid #{color}" if weights["bottom"]&.positive?
        styles["border-left"] = "#{weights["left"]}px solid #{color}" if weights["left"]&.positive?
      end

      if node["strokeDashes"].is_a?(Array) && node["strokeDashes"].any?
        styles["border-style"] = "dashed"
      end
    end

    def add_border_radius(styles, node)
      if node["cornerRadius"] && node["cornerRadius"] > 0
        styles["border-radius"] = "#{node["cornerRadius"]}px"
      elsif node["rectangleCornerRadii"]
        radii = node["rectangleCornerRadii"]
        if radii.is_a?(Array) && radii.size == 4
          styles["border-radius"] = radii.map { |r| "#{r}px" }.join(" ")
        end
      end

      if node["topLeftRadius"] || node["topRightRadius"] || node["bottomRightRadius"] || node["bottomLeftRadius"]
        tl = node["topLeftRadius"] || 0
        tr = node["topRightRadius"] || 0
        br = node["bottomRightRadius"] || 0
        bl = node["bottomLeftRadius"] || 0
        if [tl, tr, br, bl].any?(&:positive?)
          styles["border-radius"] = "#{tl}px #{tr}px #{br}px #{bl}px"
        end
      end
    end

    def add_effects(styles, effects)
      return unless effects.is_a?(Array)

      visible_effects = effects.select { |e| e["visible"] != false }
      return if visible_effects.empty?

      shadows = []
      filters = []

      visible_effects.each do |effect|
        case effect["type"]
        when "DROP_SHADOW"
          x = effect.dig("offset", "x") || 0
          y = effect.dig("offset", "y") || 0
          blur = effect["radius"] || 0
          spread = effect["spread"] || 0
          color = effect["color"] ? figma_color_to_css(effect["color"]) : "rgba(0, 0, 0, 0.25)"
          shadows << "#{x.round}px #{y.round}px #{blur.round}px #{spread.round}px #{color}"
        when "INNER_SHADOW"
          x = effect.dig("offset", "x") || 0
          y = effect.dig("offset", "y") || 0
          blur = effect["radius"] || 0
          spread = effect["spread"] || 0
          color = effect["color"] ? figma_color_to_css(effect["color"]) : "rgba(0, 0, 0, 0.25)"
          shadows << "inset #{x.round}px #{y.round}px #{blur.round}px #{spread.round}px #{color}"
        when "LAYER_BLUR"
          filters << "blur(#{effect["radius"]}px)"
        when "BACKGROUND_BLUR"
          styles["backdrop-filter"] = "blur(#{effect["radius"]}px)"
          styles["-webkit-backdrop-filter"] = "blur(#{effect["radius"]}px)"
        end
      end

      styles["box-shadow"] = shadows.join(", ") if shadows.any?
      styles["filter"] = filters.join(" ") if filters.any?
    end

    # ============================================
    # Color & Gradient Conversion
    # ============================================

    def figma_color_to_css(color, fill_opacity = nil)
      return "transparent" unless color

      r = ((color["r"] || 0) * 255).round
      g = ((color["g"] || 0) * 255).round
      b = ((color["b"] || 0) * 255).round
      color_a = color["a"] || 1
      a = fill_opacity ? (color_a * fill_opacity) : color_a

      if a < 1
        "rgba(#{r}, #{g}, #{b}, #{a.round(3)})"
      else
        "##{r.to_s(16).rjust(2, '0')}#{g.to_s(16).rjust(2, '0')}#{b.to_s(16).rjust(2, '0')}"
      end
    end

    def figma_align_to_css(align)
      case align
      when "MIN" then "flex-start"
      when "CENTER" then "center"
      when "MAX" then "flex-end"
      when "SPACE_BETWEEN" then "space-between"
      when "BASELINE" then "baseline"
      else "flex-start"
      end
    end

    def generate_linear_gradient(fill, fill_opacity = nil)
      handle_positions = fill["gradientHandlePositions"]
      return "linear-gradient(180deg, #000 0%, #fff 100%)" unless handle_positions&.size&.>= 2

      start_pos = handle_positions[0]
      end_pos = handle_positions[1]

      dx = end_pos["x"] - start_pos["x"]
      dy = end_pos["y"] - start_pos["y"]
      angle = Math.atan2(dy, dx) * 180 / Math::PI + 90

      stops = generate_gradient_stops(fill["gradientStops"], fill_opacity)
      "linear-gradient(#{angle.round}deg, #{stops})"
    end

    def generate_radial_gradient(fill, fill_opacity = nil)
      stops = generate_gradient_stops(fill["gradientStops"], fill_opacity)
      "radial-gradient(ellipse at center, #{stops})"
    end

    def generate_angular_gradient(fill, fill_opacity = nil)
      stops = generate_gradient_stops(fill["gradientStops"], fill_opacity)
      "conic-gradient(from 0deg, #{stops})"
    end

    def generate_gradient_stops(gradient_stops, fill_opacity = nil)
      return "#000 0%, #fff 100%" unless gradient_stops.is_a?(Array)

      gradient_stops.map do |stop|
        color = figma_color_to_css(stop["color"], fill_opacity)
        position = (stop["position"] * 100).round(1)
        "#{color} #{position}%"
      end.join(", ")
    end

    # ============================================
    # CSS Generation
    # ============================================

    def generate_css(css_rules)
      return "" if css_rules.empty?

      css_rules.map do |class_name, styles|
        next if styles.empty?

        ordered = order_css_properties(styles)
        props = ordered.map { |prop, value| "  #{prop}: #{value};" }.join("\n")
        ".#{class_name} {\n#{props}\n}"
      end.compact.join("\n\n")
    end

    def order_css_properties(styles)
      order = %w[
        display flex-direction flex-wrap justify-content align-items align-self
        flex-grow flex-shrink flex-basis
        position top right bottom left
        width min-width max-width height min-height max-height
        margin margin-top margin-right margin-bottom margin-left
        padding padding-top padding-right padding-bottom padding-left
        gap row-gap column-gap
        overflow
        background background-color background-image
        border border-top border-right border-bottom border-left border-radius
        box-shadow
        font-family font-size font-weight font-style line-height letter-spacing
        text-align text-decoration text-transform text-overflow white-space
        -webkit-line-clamp -webkit-box-orient
        color
        opacity visibility
        transform filter backdrop-filter -webkit-backdrop-filter
        box-sizing
      ]

      styles.sort_by do |prop, _|
        idx = order.index(prop)
        idx || 999
      end.to_h
    end

    # ============================================
    # JSX Helpers
    # ============================================

    def escape_jsx(text)
      safe_text = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      safe_text
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub("{", "&#123;")
        .gsub("}", "&#125;")
        .gsub("\u2028", "<br />")
        .gsub("\u2029", "<br />")
        .gsub("\n", "<br />")
    end

    def to_component_name(name)
      base_name = name.to_s.split(",").first&.split("=")&.last || name.to_s

      result = base_name
        .gsub(/[^a-zA-Z0-9\s_-]/, "")
        .split(/[\s_-]+/)
        .map(&:capitalize)
        .join
        .gsub(/^[0-9]+/, "")

      result.presence || "Component"
    end

    # ============================================
    # Vector Detection
    # ============================================

    def vector_frame?(node)
      return false unless node.is_a?(Hash)
      return false unless CONTAINER_TYPES.include?(node["type"])

      children = node["children"] || []
      return false if children.empty?

      children.all? { |child| vector_only?(child) }
    end

    def vector_only?(node)
      return false unless node.is_a?(Hash)

      fills = node["fills"] || []
      has_image_fill = fills.any? { |f| f["type"] == "IMAGE" && f["visible"] != false }
      return false if has_image_fill

      return true if VECTOR_TYPES.include?(node["type"])

      if CONTAINER_TYPES.include?(node["type"])
        children = node["children"] || []
        return false if children.empty?
        return children.all? { |child| vector_only?(child) }
      end

      false
    end

    def normalize_icon_name(name)
      name.to_s.downcase
        .gsub(/\s+/, "-")
        .gsub(/[^a-z0-9-]/, "")
        .gsub(/-+/, "-")
        .gsub(/^-|-$/, "")
    end
  end
end
