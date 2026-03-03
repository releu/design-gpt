# Converts a Figma node to HTML+CSS (pixel-perfect 1:1 conversion)
# Stage 1 of Figma to React pipeline - produces pure HTML that matches Figma design
module Figma
  class HtmlConverter
    include Figma::StyleExtractor

    # Default SVG cache directory
    SVG_CACHE_DIR = Rails.root.join("tmp", "figma2react_cache", "svgs")

    def initialize(figma_json, options = {})
      @figma_json = figma_json
      @options = options
      @figma_client = options[:figma_client]
      @file_key = options[:file_key]
      @component_resolver = options[:component_resolver]
      @use_cache = options.fetch(:use_cache, true)
      @cache_dir = options[:cache_dir] || SVG_CACHE_DIR
      @class_index = 0
      @css_rules = {}
      @image_refs = {}  # imageRef -> URL mapping (populated externally)
      @image_fills_found = []  # Track image refs found during processing
      @svg_contents = {}  # node_id -> SVG content mapping
      @vector_frame_ids = []  # Track frames that should be rendered as SVG
      @png_data_uris = {}  # node_id -> data URI for exported PNGs
      @image_shape_ids = []  # Track leaf shapes with IMAGE fills to export as PNG
      @fonts_used = Set.new  # Track fonts used for @font-face generation

      FileUtils.mkdir_p(@cache_dir) if @use_cache
    end

    # Set image URLs fetched from Figma API
    # Format: { "imageRef123" => "https://..." }
    def set_image_urls(image_urls)
      @image_refs = image_urls || {}
    end

    # Get all image refs found during processing (call after convert)
    def image_refs_found
      @image_fills_found.uniq
    end

    def convert
      return { error: "No Figma JSON provided" } unless @figma_json.is_a?(Hash)

      component_name = to_component_name(@figma_json["name"] || "FigmaComponent")
      scope_id = component_name.downcase.gsub(/[^a-z0-9]/, "")

      # Pre-process: find icon frames to export as SVG, and leaf image shapes to export as PNG
      collect_vector_frame_ids(@figma_json)
      collect_standalone_vector_ids(@figma_json)
      collect_image_shape_ids(@figma_json)

      # Fetch SVG exports for icon frames and standalone vectors
      fetch_svg_exports if @vector_frame_ids.any? && @figma_client && @file_key

      # Fetch PNG exports for leaf image shapes
      fetch_png_exports if @image_shape_ids.any? && @figma_client && @file_key

      # Generate HTML and CSS
      html = generate_node(@figma_json, component_name, 0, true)
      css = generate_css(@css_rules)

      # Add scope to CSS and HTML classes
      scoped_css = css.gsub(/^\.([a-z0-9_-]+)/i) { ".#{scope_id}-#{$1}" }
      scoped_html = html.gsub(/class="([^"]+)"/) { "class=\"#{scope_id}-#{$1}\"" }

      # Generate font CSS and Google Fonts URL
      font_data = generate_font_css

      {
        component_name: component_name,
        html: scoped_html,
        css: scoped_css,
        font_css: font_data[:css],
        google_fonts_url: font_data[:google_fonts_url],
        full_html: build_full_html(scoped_html, scoped_css, font_data)
      }
    end

    private

    # Collect IDs of frames that contain only vectors
    def collect_vector_frame_ids(node)
      return unless node.is_a?(Hash)

      node_id = node["id"]
      if vector_frame?(node) && node_id
        @vector_frame_ids << node_id
      else
        (node["children"] || []).each do |child|
          collect_vector_frame_ids(child)
        end
      end
    end

    # Collect IDs of standalone VECTOR nodes that are not inside vector frames
    def collect_standalone_vector_ids(node, inside_vector_frame = false)
      return unless node.is_a?(Hash)

      node_id = node["id"]

      if @vector_frame_ids.include?(node_id)
        return
      end

      if VECTOR_TYPES.include?(node["type"]) && !inside_vector_frame && node_id
        @vector_frame_ids << node_id
      end

      (node["children"] || []).each do |child|
        collect_standalone_vector_ids(child, inside_vector_frame)
      end
    end

    # Fetch SVG exports for all collected vector frames
    def fetch_svg_exports
      return if @vector_frame_ids.empty?

      # Check cache first
      uncached_ids = []
      @vector_frame_ids.each do |node_id|
        cached_svg = load_cached_svg(node_id)
        if cached_svg
          @svg_contents[node_id] = cached_svg
        else
          uncached_ids << node_id
        end
      end

      return if uncached_ids.empty?

      uncached_ids.each_slice(100) do |batch|
        begin
          response = @figma_client.export_svg(@file_key, batch)
          images = response["images"] || {}

          images.each do |node_id, url|
            next unless url.present?
            begin
              svg_content = @figma_client.fetch_svg_content(url)
              if svg_content.present?
                cleaned = clean_svg(svg_content)
                @svg_contents[node_id] = cleaned
                cache_svg(node_id, cleaned)
              end
            rescue => e
              Rails.logger.warn("Failed to fetch SVG for #{node_id}: #{e.message}")
            end
          end
        rescue => e
          Rails.logger.warn("Failed to export SVGs: #{e.message}")
        end
      end
    end

    def load_cached_svg(node_id)
      return nil unless @use_cache

      cache_key = "#{@file_key}_#{node_id.gsub(":", "-").gsub(";", "_")}"
      cache_file = @cache_dir.join("#{cache_key}.svg")

      return nil unless File.exist?(cache_file)

      cache_ttl = ENV.fetch("FIGMA_CACHE_TTL", 86400).to_i
      return nil if (Time.now - File.mtime(cache_file)) > cache_ttl

      File.read(cache_file)
    rescue => e
      Rails.logger.warn("Failed to load cached SVG for #{node_id}: #{e.message}")
      nil
    end

    def cache_svg(node_id, svg_content)
      return unless @use_cache && svg_content.present?

      cache_key = "#{@file_key}_#{node_id.gsub(":", "-").gsub(";", "_")}"
      cache_file = @cache_dir.join("#{cache_key}.svg")

      File.write(cache_file, svg_content)
    rescue => e
      Rails.logger.warn("Failed to cache SVG for #{node_id}: #{e.message}")
    end

    # Collect IDs of leaf nodes (no children) that have IMAGE fills
    def collect_image_shape_ids(node)
      return unless node.is_a?(Hash)
      return if node["visible"] == false
      return if @vector_frame_ids.include?(node["id"])

      fills = node["fills"] || []
      has_image_fill = fills.any? { |f| f["type"] == "IMAGE" && f["visible"] != false }
      children = node["children"] || []

      if has_image_fill && children.empty? && node["id"]
        @image_shape_ids << node["id"]
      else
        children.each { |child| collect_image_shape_ids(child) }
      end
    end

    # Fetch PNG exports for leaf image shapes
    def fetch_png_exports
      return if @image_shape_ids.empty?

      png_cache_dir = @cache_dir.parent.join("pngs")
      FileUtils.mkdir_p(png_cache_dir) if @use_cache

      uncached_ids = []
      @image_shape_ids.each do |node_id|
        cached_png = load_cached_png(node_id, png_cache_dir)
        if cached_png
          @png_data_uris[node_id] = cached_png
        else
          uncached_ids << node_id
        end
      end

      return if uncached_ids.empty?

      uncached_ids.each_slice(100) do |batch|
        begin
          response = @figma_client.export_png(@file_key, batch, scale: 2)
          images = response["images"] || {}

          images.each do |node_id, url|
            next unless url.present?
            begin
              png_bytes = @figma_client.fetch_binary_content(url)
              if png_bytes.present?
                data_uri = "data:image/png;base64,#{Base64.strict_encode64(png_bytes)}"
                @png_data_uris[node_id] = data_uri
                cache_png(node_id, data_uri, png_cache_dir)
              end
            rescue => e
              Rails.logger.warn("Failed to fetch PNG for #{node_id}: #{e.message}")
            end
          end
        rescue => e
          Rails.logger.warn("Failed to export PNGs: #{e.message}")
        end
      end
    end

    def load_cached_png(node_id, cache_dir)
      return nil unless @use_cache

      cache_key = "#{@file_key}_#{node_id.gsub(":", "-").gsub(";", "_")}"
      cache_file = cache_dir.join("#{cache_key}.txt")

      return nil unless File.exist?(cache_file)

      cache_ttl = ENV.fetch("FIGMA_CACHE_TTL", 86400).to_i
      return nil if (Time.now - File.mtime(cache_file)) > cache_ttl

      File.read(cache_file)
    rescue => e
      Rails.logger.warn("Failed to load cached PNG for #{node_id}: #{e.message}")
      nil
    end

    def cache_png(node_id, data_uri, cache_dir)
      return unless @use_cache && data_uri.present?

      cache_key = "#{@file_key}_#{node_id.gsub(":", "-").gsub(";", "_")}"
      cache_file = cache_dir.join("#{cache_key}.txt")

      File.write(cache_file, data_uri)
    rescue => e
      Rails.logger.warn("Failed to cache PNG for #{node_id}: #{e.message}")
    end

    def clean_svg(svg)
      return nil unless svg.present?

      svg = svg.gsub(/<\?xml[^>]+\?>/, "")
      svg = svg.gsub(/<!DOCTYPE[^>]+>/, "")
      svg = svg.gsub(/>\s+</, "><").strip
      svg
    end

    def generate_node(node, root_name, depth, is_root = false)
      return "" unless node.is_a?(Hash)
      return "" if node["visible"] == false

      type = node["type"]
      name = node["name"] || "element"
      node_id = node["id"]

      # Handle INSTANCE nodes — resolve to the original component if available
      if type == "INSTANCE" && @component_resolver && node["componentId"]
        resolved = @component_resolver.resolve(node["componentId"])
        if resolved
          # Use the resolved component's HTML/CSS directly (already converted)
          return resolved[:html] if resolved[:html].present?
        end
        # If not resolved, fall through and render the instance's own children
      end

      class_name = generate_class_name(name, is_root)

      # Check if this node has SVG content (icon frame)
      if @svg_contents[node_id]
        return generate_svg_icon(node, class_name)
      end

      # Check if this node has an exported PNG (leaf image shape)
      if @png_data_uris[node_id]
        return generate_image_shape(node, class_name)
      end

      case type
      when *CONTAINER_TYPES
        generate_frame(node, root_name, class_name, depth, is_root)
      when "TEXT"
        generate_text(node, class_name)
      when *VECTOR_TYPES
        generate_shape(node, class_name)
      else
        generate_frame(node, root_name, class_name, depth, is_root)
      end
    end

    def generate_svg_icon(node, class_name)
      styles = {}
      bbox = node["absoluteBoundingBox"] || {}
      size = node["size"] || {}

      width = size["x"] || bbox["width"]
      height = size["y"] || bbox["height"]

      styles["width"] = "#{width}px" if width
      styles["height"] = "#{height}px" if height
      styles["flex-shrink"] = "0"
      styles["position"] = "relative"
      styles["display"] = "block"

      if node["layoutSizingHorizontal"] == "FILL"
        styles["width"] = "100%"
      end
      if node["layoutSizingVertical"] == "FILL"
        styles["height"] = "100%"
      end

      @css_rules[class_name] = styles

      svg = @svg_contents[node["id"]]
      svg = svg.gsub(/<svg/, '<svg style="width:100%;height:100%;display:block"')

      "<span class=\"#{class_name}\">#{svg}</span>"
    end

    def generate_image_shape(node, class_name)
      styles = {}
      bbox = node["absoluteBoundingBox"] || {}
      size = node["size"] || {}

      width = size["x"] || bbox["width"]
      height = size["y"] || bbox["height"]

      if node["layoutSizingHorizontal"] == "FILL"
        styles["width"] = "100%"
      else
        styles["width"] = "#{width}px" if width
      end

      if node["layoutSizingVertical"] == "FILL"
        styles["height"] = "100%"
      else
        styles["height"] = "#{height}px" if height
      end

      styles["flex-shrink"] = "0"
      styles["position"] = "relative"
      styles["display"] = "block"
      styles["object-fit"] = "fill"

      add_border_radius(styles, node)
      styles["border-radius"] = "50%" if node["type"] == "ELLIPSE"

      if node["opacity"] && node["opacity"] < 1
        styles["opacity"] = node["opacity"].round(2).to_s
      end

      @css_rules[class_name] = styles

      data_uri = @png_data_uris[node["id"]]
      "<img class=\"#{class_name}\" src=\"#{data_uri}\" alt=\"\">"
    end

    def generate_class_name(name, is_root = false)
      if is_root
        "root"
      else
        suffix = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        suffix = "el" if suffix.empty?
        index = next_class_index
        "#{suffix}-#{index}"
      end
    end

    def next_class_index
      @class_index += 1
      @class_index
    end

    def generate_frame(node, root_name, class_name, depth, is_root = false)
      styles = extract_frame_styles(node, is_root)

      has_layout_mode = node["layoutMode"].present?
      children = node["children"] || []

      @css_rules[class_name] = styles

      uses_absolute_for_all = !has_layout_mode && children.any?

      item_spacing = node["itemSpacing"]
      negative_spacing = has_layout_mode && item_spacing && item_spacing < 0
      spacing_margin_prop = node["layoutMode"] == "HORIZONTAL" ? "margin-left" : "margin-top" if negative_spacing

      total_flow_children = if negative_spacing
        children.count { |c| c["layoutPositioning"] != "ABSOLUTE" && c["layoutPositioning"] != "FIXED" && c["visible"] != false }
      else
        0
      end

      flow_child_count = 0

      children_html = children.map.with_index do |child, idx|
        child_html = generate_node(child, root_name, depth + 1)

        child_is_absolute = child["layoutPositioning"] == "ABSOLUTE" || child["layoutPositioning"] == "FIXED"
        needs_absolute_wrapper = (uses_absolute_for_all || (has_layout_mode && child_is_absolute)) && child_html.present?

        if needs_absolute_wrapper
          child_styles = extract_absolute_position(child, node)
          if child_styles.any?
            wrapper_class = "#{class_name}-pos-#{idx}"
            @css_rules[wrapper_class] = child_styles.merge("position" => "absolute", "z-index" => idx.to_s)
            child_html = "<div class=\"#{wrapper_class}\">#{child_html}</div>"
          end
        elsif negative_spacing && child_html.present?
          child_class = child_html[/class="([^"]+)"/, 1]
          if child_class && @css_rules[child_class]
            if flow_child_count > 0
              @css_rules[child_class][spacing_margin_prop] = "#{item_spacing}px"
            end
            @css_rules[child_class]["z-index"] = (total_flow_children - flow_child_count).to_s
          end
          flow_child_count += 1
        end

        child_html
      end.compact.join("\n")

      indent = "  " * (depth + 1)
      children_indented = children_html.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")

      data_attr = is_root ? " data-component=\"#{root_name}\"" : ""

      if children_html.strip.empty?
        "<div class=\"#{class_name}\"#{data_attr}></div>"
      else
        "<div class=\"#{class_name}\"#{data_attr}>\n#{children_indented}\n#{"  " * depth}</div>"
      end
    end

    def generate_text(node, class_name)
      styles = extract_text_styles(node)
      @css_rules[class_name] = styles

      font_family = node.dig("style", "fontFamily")
      @fonts_used << font_family if font_family

      text = node["characters"] || ""
      overrides = node["characterStyleOverrides"] || []
      override_table = node["styleOverrideTable"] || {}

      if overrides.any? && override_table.any?
        generate_styled_text(node, class_name, text, overrides, override_table)
      else
        escaped_text = escape_html(text)
        "<div class=\"#{class_name}\">#{escaped_text}</div>"
      end
    end

    def generate_styled_text(node, class_name, text, overrides, override_table)
      segments = []
      current_segment = { override: overrides[0] || 0, chars: "" }

      text.chars.each_with_index do |char, idx|
        override_val = overrides[idx] || 0

        if override_val == current_segment[:override]
          current_segment[:chars] += char
        else
          segments << current_segment unless current_segment[:chars].empty?
          current_segment = { override: override_val, chars: char }
        end
      end
      segments << current_segment unless current_segment[:chars].empty?

      if segments.size == 1 && segments[0][:override] == 0
        escaped_text = escape_html(text)
        return "<div class=\"#{class_name}\">#{escaped_text}</div>"
      end

      segment_html = segments.map.with_index do |segment, idx|
        escaped_chars = escape_html(segment[:chars])

        if segment[:override] == 0
          escaped_chars
        else
          override_styles = override_table[segment[:override].to_s]
          if override_styles
            segment_class = "#{class_name}-s#{idx}"
            segment_css = extract_override_styles(override_styles, node["style"])
            @css_rules[segment_class] = segment_css
            "<span class=\"#{segment_class}\">#{escaped_chars}</span>"
          else
            escaped_chars
          end
        end
      end.join("")

      "<div class=\"#{class_name}\">#{segment_html}</div>"
    end

    def extract_override_styles(override, base_style)
      styles = {}

      if override["fills"].is_a?(Array)
        visible_fill = override["fills"].find { |f| f["visible"] != false && f["type"] == "SOLID" }
        if visible_fill && visible_fill["color"]
          styles["color"] = figma_color_to_css(visible_fill["color"], visible_fill["opacity"])
        end
      end

      styles["font-family"] = "\"#{override["fontFamily"]}\", sans-serif" if override["fontFamily"]
      styles["font-size"] = "#{override["fontSize"]}px" if override["fontSize"]
      styles["font-weight"] = override["fontWeight"].to_s if override["fontWeight"]
      styles["font-style"] = "italic" if override["italic"]

      if override["textDecoration"] == "UNDERLINE"
        styles["text-decoration"] = "underline"
      elsif override["textDecoration"] == "STRIKETHROUGH"
        styles["text-decoration"] = "line-through"
      end

      styles
    end

    def generate_shape(node, class_name)
      styles = extract_shape_styles(node)
      @css_rules[class_name] = styles

      "<div class=\"#{class_name}\"></div>"
    end

    def handle_image_fill(fill)
      image_ref = fill["imageRef"]
      return nil unless image_ref

      @image_fills_found << image_ref

      if @image_refs[image_ref]
        @current_element_has_image = true
        @current_image_scale_mode = fill["scaleMode"] || "FILL"
        @current_image_transform = fill["imageTransform"]
        "url(#{@image_refs[image_ref]})"
      else
        "#e0e0e0"
      end
    end

    def add_fills(styles, fills)
      @current_element_has_image = false
      @current_image_scale_mode = nil
      @current_image_transform = nil
      super
      if @current_element_has_image
        case @current_image_scale_mode
        when "STRETCH"
          if @current_image_transform.is_a?(Array) && @current_image_transform.length >= 2
            scale_x = @current_image_transform[0][0] rescue 1.0
            translate_x = @current_image_transform[0][2] rescue 0.0
            scale_y = @current_image_transform[1][1] rescue 1.0
            translate_y = @current_image_transform[1][2] rescue 0.0

            size_x = scale_x > 0 ? (100.0 / scale_x).round(2) : 100.0
            size_y = scale_y > 0 ? (100.0 / scale_y).round(2) : 100.0

            pos_x = translate_x > 0 ? (-translate_x * size_x).round(2) : 0.0
            pos_y = translate_y > 0 ? (-translate_y * size_y).round(2) : 0.0

            styles["background-size"] = "#{size_x}% #{size_y}%"
            styles["background-position"] = "#{pos_x}% #{pos_y}%"
          else
            styles["background-size"] = "100% 100%"
            styles["background-position"] = "0 0"
          end
          styles["background-repeat"] = "no-repeat"
        when "FIT"
          styles["background-size"] = "contain"
          styles["background-position"] = "center"
          styles["background-repeat"] = "no-repeat"
        when "TILE"
          styles["background-repeat"] = "repeat"
        else # FILL or CROP
          styles["background-size"] = "cover"
          styles["background-position"] = "center"
          styles["background-repeat"] = "no-repeat"
        end
      end
    end

    def escape_html(text)
      safe_text = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      safe_text
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub('"', "&quot;")
        .gsub("'", "&#39;")
        .gsub("\u2028", "<br>")
        .gsub("\u2029", "<br>")
        .gsub("\n", "<br>")
    end

    # Google Fonts that can be loaded via CDN
    GOOGLE_FONTS = {
      "Inter" => "Inter:wght@100;200;300;400;500;600;700;800;900",
      "Roboto" => "Roboto:wght@100;300;400;500;700;900",
      "Open Sans" => "Open+Sans:wght@300;400;500;600;700;800",
      "Lato" => "Lato:wght@100;300;400;700;900",
      "Montserrat" => "Montserrat:wght@100;200;300;400;500;600;700;800;900",
      "Poppins" => "Poppins:wght@100;200;300;400;500;600;700;800;900",
      "Source Sans Pro" => "Source+Sans+Pro:wght@200;300;400;600;700;900",
      "Nunito" => "Nunito:wght@200;300;400;500;600;700;800;900",
      "Raleway" => "Raleway:wght@100;200;300;400;500;600;700;800;900",
      "Ubuntu" => "Ubuntu:wght@300;400;500;700",
      "Playfair Display" => "Playfair+Display:wght@400;500;600;700;800;900",
      "Merriweather" => "Merriweather:wght@300;400;700;900",
      "PT Sans" => "PT+Sans:wght@400;700",
      "Noto Sans" => "Noto+Sans:wght@100;200;300;400;500;600;700;800;900",
      "Work Sans" => "Work+Sans:wght@100;200;300;400;500;600;700;800;900",
      "Fira Sans" => "Fira+Sans:wght@100;200;300;400;500;600;700;800;900",
      "DM Sans" => "DM+Sans:wght@400;500;700",
      "Space Grotesk" => "Space+Grotesk:wght@300;400;500;600;700",
    }.freeze

    def generate_font_css
      return { css: "", google_fonts_url: nil } if @fonts_used.empty?

      google_fonts = []
      local_fonts = []

      @fonts_used.each do |font_family|
        next unless font_family

        if GOOGLE_FONTS[font_family]
          google_fonts << GOOGLE_FONTS[font_family]
        else
          local_css = generate_font_face(font_family)
          local_fonts << local_css if local_css.present?
        end
      end

      google_fonts_url = nil
      if google_fonts.any?
        families = google_fonts.join("&family=")
        google_fonts_url = "https://fonts.googleapis.com/css2?family=#{families}&display=swap"
      end

      {
        css: local_fonts.join("\n"),
        google_fonts_url: google_fonts_url
      }
    end

    def generate_font_face(font_family)
      font_dir = Rails.root.join("test", "fonts", font_family)
      return nil unless Dir.exist?(font_dir)

      css_file = font_dir.join("fonts.css")
      if File.exist?(css_file)
        css = File.read(css_file)
        css = css.gsub(/url\("([^"]+)"\)/) do |match|
          url = $1
          if url.start_with?("http") || url.start_with?("file://")
            match
          else
            "url(\"file://#{font_dir.join(url)}\")"
          end
        end
        declared_family = css.match(/font-family:\s*"([^"]+)"/)&.[](1)
        if declared_family && declared_family != font_family
          extra_rules = css.gsub("\"#{declared_family}\"", "\"#{font_family}\"")
          return css + "\n" + extra_rules
        end
        return css
      end

      weights = {
        "Thin" => 100,
        "ExtraLight" => 200,
        "Light" => 300,
        "Regular" => 400,
        "Medium" => 500,
        "SemiBold" => 600,
        "Bold" => 700,
        "ExtraBold" => 800,
        "Black" => 900,
        "Heavy" => 800
      }

      css = []
      font_files = Dir.glob(font_dir.join("*.{woff2,woff,ttf}"))

      font_files.each do |font_file|
        ext = File.extname(font_file).delete(".")
        filename = File.basename(font_file, ".*")

        format = case ext
                 when "woff2" then "woff2"
                 when "woff" then "woff"
                 when "ttf" then "truetype"
                 end

        weight = 400
        weights.each do |name, val|
          if filename.downcase.include?(name.downcase)
            weight = val
            break
          end
        end

        font_style = filename.downcase.include?("italic") ? "italic" : "normal"

        css << <<~CSS
          @font-face {
            font-family: "#{font_family}";
            src: url("file://#{font_file}") format("#{format}");
            font-weight: #{weight};
            font-style: #{font_style};
          }
        CSS
      end

      css.join("\n")
    end

    def build_full_html(html, css, font_data)
      google_fonts_link = if font_data[:google_fonts_url]
        "<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n  <link href=\"#{font_data[:google_fonts_url]}\" rel=\"stylesheet\">"
      else
        ""
      end

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          #{google_fonts_link}
          <style>
            * { margin: 0; padding: 0; }
            #{font_data[:css]}
            #{css}
          </style>
        </head>
        <body>
          #{html}
        </body>
        </html>
      HTML
    end
  end
end
