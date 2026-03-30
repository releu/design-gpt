# Shared module for extracting CSS styles from Figma JSON
# Used by both Figma::ReactFactory (design system components) and Figma::HtmlConverter (1:1 conversion)
module Figma
  module StyleExtractor
    VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
    CONTAINER_TYPES = %w[FRAME GROUP COMPONENT COMPONENT_SET INSTANCE SECTION].freeze

    # ============================================
    # Style Extraction
    # ============================================

    def extract_frame_styles(node, is_root = false, parent_layout_mode: nil, is_page_root: false)
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
        if item_spacing && item_spacing > 0
          styles["gap"] = "#{item_spacing}px"
        elsif item_spacing && item_spacing < 0
          # Negative spacing creates overlapping children (e.g. AvatarStack).
          # CSS gap doesn't support negatives, so use negative margin on children.
          direction = node["layoutMode"] == "VERTICAL" ? "margin-top" : "margin-left"
          styles["--negative-spacing"] = "#{item_spacing}px"
          styles["--negative-spacing-direction"] = direction
          styles["--negative-spacing-reverse-z"] = "true" if node["itemReverseZIndex"]
        end

        counter_spacing = node["counterAxisSpacing"]
        if counter_spacing && counter_spacing > 0 && node["layoutWrap"] == "WRAP"
          styles["row-gap"] = "#{counter_spacing}px"
        end

        styles["flex-wrap"] = "wrap" if node["layoutWrap"] == "WRAP"
      end

      styles["position"] = "relative"

      # Sizing mode
      primary_sizing = node["primaryAxisSizingMode"]
      counter_sizing = node["counterAxisSizingMode"]

      layout_sizing_h = node["layoutSizingHorizontal"]
      layout_sizing_v = node["layoutSizingVertical"]

      if layout_mode == "HORIZONTAL"
        if layout_sizing_h != "FILL"
          if primary_sizing == "FIXED"
            styles["width"] = "#{width}px"
          elsif primary_sizing == "HUG"
            styles["width"] = "fit-content"
          end
        end

        if layout_sizing_v != "FILL"
          if counter_sizing == "FIXED"
            styles["height"] = "#{height}px"
          elsif counter_sizing == "HUG"
            styles["height"] = "fit-content"
          end
        end
      elsif layout_mode == "VERTICAL"
        if layout_sizing_h != "FILL"
          if counter_sizing == "FIXED"
            styles["width"] = "#{width}px"
          elsif counter_sizing == "HUG"
            styles["width"] = "fit-content"
          end
        end

        if layout_sizing_v != "FILL"
          if primary_sizing == "FIXED"
            styles["height"] = "#{height}px"
          elsif primary_sizing == "HUG"
            styles["height"] = "fit-content"
          end
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

      own_width_fixed = (layout_mode == "HORIZONTAL" && primary_sizing == "FIXED") ||
                        (layout_mode == "VERTICAL" && counter_sizing == "FIXED")
      own_height_fixed = (layout_mode == "VERTICAL" && primary_sizing == "FIXED") ||
                         (layout_mode == "HORIZONTAL" && counter_sizing == "FIXED")

      if layout_sizing_h == "FILL"
        if parent_layout_mode == "HORIZONTAL"
          # Main axis in row parent → flex-grow
          unless node["layoutGrow"] && node["layoutGrow"] > 0
            styles["flex-grow"] = "1"
            styles["flex-basis"] = "0"
            styles["min-width"] ||= "0"
          end
        else
          # Cross axis in column parent → align-self: stretch
          styles["align-self"] = "stretch"
        end
      elsif layout_sizing_h == "HUG" && !own_width_fixed
        # Empty frames with HUG collapse to 0 — use fixed dimensions instead
        has_children = (node["children"] || []).any?
        styles["width"] = has_children ? "fit-content" : "#{width}px"
      elsif layout_sizing_h == "FIXED"
        styles["width"] = "#{width}px"
      end

      if layout_sizing_v == "FILL"
        if parent_layout_mode == "VERTICAL"
          # Main axis in column parent → flex-grow
          unless node["layoutGrow"] && node["layoutGrow"] > 0
            styles["flex-grow"] = "1"
            styles["flex-basis"] = "0"
            styles["min-height"] ||= "0"
          end
        else
          # Cross axis in row parent → align-self: stretch
          styles["align-self"] = "stretch"
        end
      elsif layout_sizing_v == "HUG" && !own_height_fixed
        has_children = (node["children"] || []).any?
        if has_children
          styles["height"] = "fit-content"
          styles["max-height"] = "#{height}px" if height && node["clipsContent"]
        else
          styles["height"] = "#{height}px"
        end
      elsif layout_sizing_v == "FIXED"
        styles["height"] = "#{height}px"
      end

      # Detect semi-transparent fills early — needed for root width decision below.
      node_fills = node["fills"] || []
      has_semitransparent_fill = node_fills.any? do |f|
        next false unless f["visible"] != false && f["type"] == "SOLID"
        color_a = (f.dig("color", "a") || 1.0).to_f
        fill_opacity = (f["opacity"] || 1.0).to_f
        (color_a * fill_opacity).between?(0.01, 0.99)
      end

      if is_root
        if is_page_root
          # Page-level root: keep Figma dimensions (width + min-height)
          styles["width"] = "#{width}px" if width
          styles["min-height"] = "#{height}px" if height
          styles.delete("height")
        else
          # Child component roots: flexible sizing, parent context controls dimensions.
          # SLOT `> *` rules override these when used as slot children.
          styles.delete("height") if styles["height"] =~ /\d+(\.\d+)?px/
          if styles["width"] =~ /\d+(\.\d+)?px/
            styles["width"] = "100%"
          end
        end
        styles.delete("max-height")
        styles.delete("max-width")
      end

      if node["layoutAlign"] == "STRETCH"
        styles["align-self"] = "stretch"
      end

      unless node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-shrink"] = "0"
      end

      add_padding(styles, node)
      add_fills(styles, node["fills"])

      # No default background for components — transparent unless Figma specifies fills

      add_strokes(styles, node)
      add_border_radius(styles, node)
      add_effects(styles, node["effects"])

      # Treat all scrolling frames as static clipped content — no scroll in our renderer.
      # Skip overflow:hidden when the node has drop shadows, since CSS overflow clips shadows too.
      if node["clipsContent"]
        has_shadow = (node["effects"] || []).any? { |e| e["type"] == "DROP_SHADOW" && e["visible"] != false }
        styles["overflow"] = "hidden" unless has_shadow
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      styles["display"] = "none" if node["visible"] == false

      styles["box-sizing"] ||= "border-box"

      styles
    end

    def extract_text_styles(node, parent_layout_mode: nil)
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
      # Only apply flex-based vertical alignment when the text box has a fixed height.
      # For HUG-sized text nodes the box height equals the content height, so
      # textAlignVertical is visually irrelevant and adding display:flex can subtly
      # affect font rendering vs. Figma's native text rendering.
      if text_align_vertical && text_align_vertical != "TOP" && node["layoutSizingVertical"] != "HUG"
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
        # Only nowrap if text actually fits on one line.
        # If bbox height > ~1.5x line height, text is wrapping in Figma.
        line_height = node.dig("style", "lineHeightPx") || node.dig("style", "fontSize") || 16
        bbox_height = node.dig("absoluteBoundingBox", "height") || 0
        if bbox_height <= line_height * 1.5
          styles["white-space"] = "nowrap"
        end
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      layout_sizing_h = node["layoutSizingHorizontal"]
      layout_sizing_v = node["layoutSizingVertical"]

      if layout_sizing_h == "FILL"
        if parent_layout_mode == "HORIZONTAL"
          unless node["layoutGrow"] && node["layoutGrow"] > 0
            styles["flex-grow"] = "1"
            styles["flex-basis"] = "0"
            styles["min-width"] ||= "0"
          end
        else
          styles["align-self"] = "stretch"
        end
      elsif layout_sizing_h == "FIXED"
        bbox = node["absoluteBoundingBox"] || {}
        styles["width"] = "#{bbox["width"]}px" if bbox["width"]
      elsif layout_sizing_h == "HUG"
        # For non-left-aligned HUG text, set the bounding-box width explicitly so that
        # text-align: right/center has room to work. Without an explicit width the span
        # collapses to content width and the alignment is a visual no-op, causing a
        # horizontal offset vs Figma where glyphs are right/center-positioned within the box.
        text_align_h = (node["style"] || {})["textAlignHorizontal"]
        if text_align_h && text_align_h != "LEFT"
          bbox = node["absoluteBoundingBox"] || {}
          styles["width"] = "#{bbox["width"]}px" if bbox["width"]
        end
      end

      if layout_sizing_v == "FILL"
        if parent_layout_mode == "VERTICAL"
          unless node["layoutGrow"] && node["layoutGrow"] > 0
            styles["flex-grow"] = "1"
            styles["flex-basis"] = "0"
            styles["min-height"] ||= "0"
          end
        else
          styles["align-self"] = "stretch"
        end
      elsif layout_sizing_v == "FIXED"
        bbox ||= node["absoluteBoundingBox"] || {}
        styles["height"] = "#{bbox["height"]}px" if bbox["height"]
      end

      if node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-grow"] = node["layoutGrow"].to_s
        styles["flex-basis"] = "0"
        styles["flex-shrink"] = "1"
      else
        styles["flex-shrink"] = "0"
      end
      styles["position"] = "relative"
      styles["margin"] = "0"
      styles["-webkit-font-smoothing"] = "antialiased"
      styles["-moz-osx-font-smoothing"] = "grayscale"
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
        unless node["layoutGrow"] && node["layoutGrow"] > 0
          styles["flex-grow"] = "1"
          styles["flex-basis"] = "0"
          styles["min-width"] = "0"
        end
      else
        styles["width"] = "#{width}px" if width
      end

      if layout_sizing_v == "FILL"
        unless node["layoutGrow"] && node["layoutGrow"] > 0
          styles["flex-grow"] = "1"
          styles["flex-basis"] = "0"
          styles["min-height"] = "0"
        end
      else
        styles["height"] = "#{height}px" if height
      end

      if node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-grow"] = node["layoutGrow"].to_s
        styles["flex-basis"] = "0"
      end

      unless node["layoutGrow"] && node["layoutGrow"] > 0
        styles["flex-shrink"] = "0"
      end

      styles["border-radius"] = "50%" if node["type"] == "ELLIPSE"

      if node["type"] == "LINE"
        # Determine orientation from bounding box: height > width means vertical line
        line_bbox = node["absoluteBoundingBox"] || {}
        line_is_vertical = (line_bbox["height"] || 0) > (line_bbox["width"] || 0)
        if line_is_vertical
          styles["width"] = "0"
          styles.delete("height")  # height handled by flex-grow in vertical container
        else
          styles["height"] = "0"
        end
      end

      add_fills(styles, node["fills"])
      add_strokes(styles, node)

      # For LINE nodes, convert full border to the appropriate directional border
      if node["type"] == "LINE" && styles["border"]
        line_bbox = node["absoluteBoundingBox"] || {}
        line_is_vertical = (line_bbox["height"] || 0) > (line_bbox["width"] || 0)
        if line_is_vertical
          styles["border-left"] = styles.delete("border")
        else
          styles["border-top"] = styles.delete("border")
        end
      end
      add_border_radius(styles, node) unless node["type"] == "ELLIPSE"
      add_effects(styles, node["effects"])

      # Skip rotation for LINE nodes — orientation is determined from bounding box dimensions
      if node["rotation"] && node["rotation"] != 0 && node["type"] != "LINE"
        styles["transform"] = "rotate(#{-node["rotation"]}deg)"
      end

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      styles["position"] = "relative"
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
        styles["right"] = fmt_px(parent_x + parent_w - node_x - node_w)
      when "LEFT_RIGHT"
        styles["left"] = fmt_px(node_x - parent_x)
        styles["right"] = fmt_px(parent_x + parent_w - node_x - node_w)
      when "CENTER"
        styles["left"] = fmt_px(node_x - parent_x)
      else # LEFT
        styles["left"] = fmt_px(node_x - parent_x)
      end

      case v_constraint
      when "BOTTOM"
        styles["bottom"] = fmt_px(parent_y + parent_h - node_y - node_h)
      when "TOP_BOTTOM"
        styles["top"] = fmt_px(node_y - parent_y)
        styles["bottom"] = fmt_px(parent_y + parent_h - node_y - node_h)
      when "CENTER"
        styles["top"] = fmt_px(node_y - parent_y)
      else # TOP
        styles["top"] = fmt_px(node_y - parent_y)
      end

      styles
    end

    # ============================================
    # Style Helpers
    # ============================================

    def fmt_px(val)
      r = val.round(1)
      r == r.to_i.to_f ? "#{r.to_i}px" : "#{r}px"
    end

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
        # Use content-box so the border extends outside the content area.
        # The pipeline forces the element's inline width/height to the Figma bounding box
        # (content size), which in content-box mode keeps the total rendered element at the
        # Figma render-bounds size — matching the Figma screenshot dimensions exactly.
        width_px = styles["width"]&.match(/^([\d.]+)px$/)&.[](1)&.to_f
        height_px = styles["height"]&.match(/^([\d.]+)px$/)&.[](1)&.to_f
        if width_px || height_px
          styles["border"] = "#{weight}px solid #{color}"
          styles["box-sizing"] = "content-box"
          # Don't expand width/height — content-box + border naturally adds weight px on each side
        else
          shadow = "0 0 0 #{weight}px #{color}"
          styles["box-shadow"] = existing_shadow ? "#{existing_shadow}, #{shadow}" : shadow
        end
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
      # For OUTSIDE strokes rendered as CSS border (not box-shadow), the border-radius
      # must include the stroke weight so the outer edge matches the Figma design.
      outside_stroke_offset = if node["strokeAlign"] == "OUTSIDE" && styles["border"]
        node["strokeWeight"] || 1
      else
        0
      end

      if node["cornerRadius"] && node["cornerRadius"] > 0
        styles["border-radius"] = "#{node["cornerRadius"] + outside_stroke_offset}px"
      elsif node["rectangleCornerRadii"]
        radii = node["rectangleCornerRadii"]
        if radii.is_a?(Array) && radii.size == 4 && radii.any? { |r| r > 0 }
          styles["border-radius"] = radii.map { |r| "#{r + outside_stroke_offset}px" }.join(" ")
        end
      end

      if node["topLeftRadius"] || node["topRightRadius"] || node["bottomRightRadius"] || node["bottomLeftRadius"]
        tl = (node["topLeftRadius"] || 0) + outside_stroke_offset
        tr = (node["topRightRadius"] || 0) + outside_stroke_offset
        br = (node["bottomRightRadius"] || 0) + outside_stroke_offset
        bl = (node["bottomLeftRadius"] || 0) + outside_stroke_offset
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
          if effect["showShadowBehindNode"]
            # filter: drop-shadow respects actual rendered content (transparency, border-radius),
            # matching Figma's "Show shadow behind transparent areas" behaviour.
            # Note: drop-shadow() has no spread parameter, so spread is intentionally omitted.
            filters << "drop-shadow(#{x.round}px #{y.round}px #{blur.round}px #{color})"
          else
            shadows << "#{x.round}px #{y.round}px #{blur.round}px #{spread.round}px #{color}"
          end
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

    # Convert a Figma GRADIENT_LINEAR fill used as an alpha mask into a CSS mask-image gradient.
    # Uses only the alpha channel of each stop (ignores RGB), so the mask image controls
    # transparency: fully-opaque stops reveal the masked layer, transparent stops hide it.
    def alpha_mask_gradient(fill)
      handle_positions = fill["gradientHandlePositions"]
      return nil unless handle_positions&.size&.>= 2

      start_pos = handle_positions[0]
      end_pos = handle_positions[1]

      dx = end_pos["x"] - start_pos["x"]
      dy = end_pos["y"] - start_pos["y"]
      angle = Math.atan2(dy, dx) * 180 / Math::PI + 90

      stops = (fill["gradientStops"] || []).map do |stop|
        alpha = stop.dig("color", "a") || 1.0
        position = (stop["position"] * 100).round(1)
        "rgba(0, 0, 0, #{alpha.round(3)}) #{position}%"
      end.join(", ")

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
        -webkit-font-smoothing -moz-osx-font-smoothing
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
      base_name = base_name.strip

      # Already valid PascalCase: starts with uppercase, only alphanumeric
      return base_name if base_name.match?(/\A[A-Z][a-zA-Z0-9]*\z/)

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

    COMPLEX_VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION STAR POLYGON].freeze

    def vector_frame?(node)
      return false unless node.is_a?(Hash)
      return false unless CONTAINER_TYPES.include?(node["type"])

      children = node["children"] || []
      return false if children.empty?
      return false unless children.all? { |child| vector_only?(child) }

      # Skip trivial shapes (single rectangle, ellipse, line) — CSS handles these.
      has_complex_vector?(node)
    end

    def has_complex_vector?(node)
      return false unless node.is_a?(Hash)
      return true if COMPLEX_VECTOR_TYPES.include?(node["type"])

      (node["children"] || []).any? { |child| has_complex_vector?(child) }
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
