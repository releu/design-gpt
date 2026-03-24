# Figma node -> JSX + CSS code generation.
# Takes Figma JSON nodes and produces React component code strings.
# Uses Resolver for component lookups, prop resolution, etc.
module Figma
  class Emitter
    include Figma::StyleExtractor

    attr_reader :css_rules
    attr_accessor :has_slot

    def initialize(component_name, resolver:)
      @component_name = component_name
      @resolver = resolver
      @class_index = 0
      @css_rules = {}
      @has_slot = false
      @current_props = {}
      @prop_definitions = {}
      @slot_map = {}
      @nested_instance_props = {}
      @is_list_component = false
      @rendered_list_slots = []
    end

    # Set mutable state before generating a component
    def configure(current_props:, prop_definitions:, slot_map:, nested_instance_props:,
                  is_list_component: false, rendered_list_slots: [])
      @current_props = current_props
      @prop_definitions = prop_definitions
      @slot_map = slot_map
      @nested_instance_props = nested_instance_props
      @is_list_component = is_list_component
      @rendered_list_slots = rendered_list_slots
      @class_index = 0
      @css_rules = {}
      @has_slot = false
    end

    # --- IR-based emission (for standalone emitter tests) ---

    def emit_node(ir_node, depth = 0, is_root: false)
      return "" unless ir_node

      jsx = case ir_node[:kind]
      when :frame then emit_frame(ir_node, depth, is_root: is_root)
      when :text then emit_text(ir_node, depth)
      when :shape then emit_shape(ir_node, depth)
      when :component_ref then emit_component_ref(ir_node)
      when :slot then emit_slot(ir_node)
      when :icon_swap then emit_icon_swap(ir_node)
      when :image_swap then emit_image_swap(ir_node)
      when :svg_inline then emit_svg_inline(ir_node, depth)
      when :png_inline then emit_png_inline(ir_node, depth)
      when :unresolved then emit_unresolved(ir_node, depth)
      else ""
      end

      if ir_node[:visibility_prop]
        prop = ir_node[:visibility_prop]
        if jsx.start_with?("{") && jsx.end_with?("}")
          inner_expr = jsx[1..-2]
          jsx = "{#{prop} && (#{inner_expr})}"
        else
          jsx = "{#{prop} && (#{jsx})}"
        end
      end

      jsx
    end

    # --- Figma JSON-based generation (moved from ReactFactory) ---

    def generate_node(node, root_name, css_rules, depth, is_root = false)
      return "" unless node.is_a?(Hash)

      prop_refs = node["componentPropertyReferences"] || {}
      visibility_ref = prop_refs["visible"]

      if visibility_ref
        prop = @resolver.find_prop_for_reference(visibility_ref, @current_props)
        if prop
          if prop[:type] != "BOOLEAN"
            return "" if node["visible"] == false
          end
        else
          return "" if node["visible"] == false
        end
      else
        return "" if node["visible"] == false
      end

      type = node["type"]
      name = node["name"] || "element"

      class_name = generate_class_name_legacy(root_name, name, is_root)

      jsx = if node["_detached"] && node["_was_instance"]
        generate_detached_instance(node, root_name, class_name, css_rules, depth)
      else
        case type
        when "COMPONENT", "COMPONENT_SET", "FRAME", "GROUP"
          generate_frame(node, root_name, class_name, css_rules, depth, is_root)
        when "TEXT"
          generate_text_node(node, root_name, class_name, css_rules, depth)
        when *VECTOR_TYPES
          generate_shape_node(node, root_name, class_name, css_rules, depth)
        when "SLOT"
          @has_slot = true
          slot_name = @slot_map[node["id"]] || "children"
          styles = extract_frame_styles(node, false)
          styles["min-width"] = "0" if styles["flex-grow"] || styles["align-self"]
          styles["overflow"] = "hidden" if styles["flex-grow"]
          css_rules[class_name] = styles
          "<div className=\"#{class_name}\">{props.#{slot_name}}</div>"
        when "INSTANCE"
          ref = node["componentPropertyReferences"]&.dig("mainComponent")
          if @is_list_component && ref && @resolver.instance_swap_ref?(ref, @prop_definitions)
            if @rendered_list_slots.include?(ref)
              ""
            else
              @rendered_list_slots << ref
              @has_slot = true
              slot_name = @slot_map[node["id"]] || "children"
              "{props.#{slot_name}}"
            end
          elsif @resolver.image_swap_instance?(node, @prop_definitions)
            ref = node["componentPropertyReferences"]["mainComponent"]
            prop_name = @resolver.to_prop_name(@resolver.strip_ref_suffix(ref))
            styles = extract_frame_styles(node, false) rescue {}
            css_rules[class_name] = styles if styles.any?
            wrap_class = styles.any? ? " className=\"#{class_name}\"" : ""
            "<div#{wrap_class} style={{width: '100%', height: '100%', backgroundImage: props.#{prop_name} ? `url(https://design-gpt.xyz/api/images/render?prompt=${encodeURIComponent(props.#{prop_name})})` : 'none', backgroundSize: 'cover', backgroundPosition: 'center'}} />"
          elsif @resolver.slot_instance?(node, @prop_definitions)
            @has_slot = true
            slot_name = @slot_map[node["id"]] || "children"
            "{props.#{slot_name}}"
          elsif (swap_prop = @resolver.instance_swap_prop_name(node, @prop_definitions))
            overrides = @resolver.extract_instance_style_overrides(node)
            if overrides.any?
              style_pairs = overrides.map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
              "{#{swap_prop} && <#{swap_prop} style={{#{style_pairs}}} />}"
            else
              "{#{swap_prop} && <#{swap_prop} />}"
            end
          else
            generate_instance(node, root_name, class_name, css_rules, depth)
          end
        else
          generate_frame(node, root_name, class_name, css_rules, depth, is_root)
        end
      end

      if visibility_ref
        prop = @resolver.find_prop_for_reference(visibility_ref, @current_props)
        if prop && prop[:type] == "BOOLEAN"
          if jsx.start_with?("{") && jsx.end_with?("}")
            inner_expr = jsx[1..-2]
            jsx = "{#{prop[:name]} && (#{inner_expr})}"
          else
            jsx = "{#{prop[:name]} && (#{jsx})}"
          end
        end
      end

      jsx
    end

    def generate_frame(node, root_name, class_name, css_rules, depth, is_root = false)
      styles = extract_frame_styles(node, is_root)
      css_rules[class_name] = styles

      node_id = node["id"]
      if !is_root && @resolver.inline_pngs_by_node_id[node_id]
        return "<img className=\"#{class_name}\" src={\"data:image/png;base64,#{@resolver.inline_pngs_by_node_id[node_id]}\"} />"
      end
      if !is_root && vector_frame?(node) && @resolver.inline_svgs_by_node_id[node_id]
        has_resolvable_instance = (node["children"] || []).any? { |child|
          child["type"] == "INSTANCE" && child["componentId"] && (
            @resolver.components_by_node_id[child["componentId"]] ||
            @resolver.component_sets_by_node_id[child["componentId"]] ||
            @resolver.variants_by_node_id[child["componentId"]] ||
            (@resolver.component_key_by_node_id[child["componentId"]] && @resolver.variants_by_component_key[@resolver.component_key_by_node_id[child["componentId"]]])
          )
        }
        unless has_resolvable_instance
          svg_content = @resolver.inline_svgs_by_node_id[node_id].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          clean_svg = svg_content
            .gsub(/<\?xml[^>]*\?>/, "")
            .gsub(/xmlns="[^"]*"/, "")
            .strip
          return "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
        end
      end

      uses_absolute = !node["layoutMode"] && (node["children"] || []).any?

      children_jsx = (node["children"] || []).map.with_index do |child, idx|
        child_jsx = generate_node(child, root_name, css_rules, depth + 1)

        if child_jsx.present? && uses_absolute
          child_styles = extract_absolute_position(child, node)
          if child_styles.any?
            wrapper_class = "#{class_name}-pos-#{idx}"
            css_rules[wrapper_class] = child_styles.merge("position" => "absolute")
            child_jsx = "<div className=\"#{wrapper_class}\">#{child_jsx}</div>"
          end
        end

        child_jsx
      end.compact.join("\n")

      indent = "  " * (depth + 2)
      children_indented = children_jsx.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")

      data_attr = is_root ? " data-component=\"#{root_name}\"" : ""

      if children_jsx.strip.empty?
        "<div className=\"#{class_name}\"#{data_attr} />"
      else
        "<div className=\"#{class_name}\"#{data_attr}>\n#{children_indented}\n#{"  " * (depth + 1)}</div>"
      end
    end

    def generate_text_node(node, root_name, class_name, css_rules, depth)
      styles = extract_text_styles(node)
      css_rules[class_name] = styles

      text = node["characters"] || ""

      prop_refs = node["componentPropertyReferences"] || {}
      characters_ref = prop_refs["characters"]

      if characters_ref
        prop = @resolver.find_prop_for_reference(characters_ref, @current_props)
        if prop && prop[:type] == "TEXT"
          return "<span className=\"#{class_name}\">{#{prop[:name]}}</span>"
        end
      end

      escaped_text = escape_jsx(text)
      "<span className=\"#{class_name}\">#{escaped_text}</span>"
    end

    def generate_shape_node(node, root_name, class_name, css_rules, depth)
      styles = extract_shape_styles(node)

      node_id = node["id"]
      if @resolver.inline_pngs_by_node_id[node_id]
        css_rules[class_name] = styles
        return "<img className=\"#{class_name}\" src={\"data:image/png;base64,#{@resolver.inline_pngs_by_node_id[node_id]}\"} />"
      end
      if @resolver.inline_svgs_by_node_id[node_id]
        svg_content = @resolver.inline_svgs_by_node_id[node_id].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        clean_svg = svg_content
          .gsub(/<\?xml[^>]*\?>/, "")
          .gsub(/xmlns="[^"]*"/, "")
          .strip
        styles.delete("background")
        css_rules[class_name] = styles
        return "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
      end

      css_rules[class_name] = styles
      "<div className=\"#{class_name}\" />"
    end

    def generate_detached_instance(node, root_name, class_name, css_rules, depth)
      original_component_id = node["_original_component_id"]
      name = node["name"] || "icon"

      prop_refs = node["componentPropertyReferences"] || {}
      main_component_ref = prop_refs["mainComponent"]

      component_set = @resolver.find_component_set_for_detached(node)

      if component_set
        component_name = to_component_name(component_set.name)
        instance_key = node["_instance_key"]

        if instance_key
          props_parts = []
          prop_definitions = component_set.prop_definitions || {}

          prop_definitions.each do |key, definition|
            if definition["type"] == "TEXT"
              clean_name = key.gsub(/#[\d:]+$/, "").strip
              original_prop_name = @resolver.to_prop_name(clean_name)
              namespaced_prop_name = "#{instance_key}#{original_prop_name.sub(/^(\w)/) { $1.upcase }}"
              if @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_prop_name}={#{namespaced_prop_name}}"
              end
            elsif definition["type"] == "INSTANCE_SWAP"
              clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s\u21B3]+/, "")
              original_prop_name = @resolver.to_prop_name(clean_name)
              original_component_name = original_prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
              namespaced_prop_name = "#{instance_key}#{original_component_name}"
              if @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_component_name}={#{namespaced_prop_name}}"
              end
            end
          end

          props_string = props_parts.empty? ? "" : " " + props_parts.join(" ")
        else
          overridden_props = @resolver.extract_overridden_props(node, component_set)
          props_string = overridden_props.map { |k, v| "#{k}={#{v}}" }.join(" ")
          props_string = " " + props_string unless props_string.empty?
        end

        if main_component_ref
          prop = @resolver.find_prop_for_reference(main_component_ref, @current_props)
          if prop && prop[:type] == "INSTANCE_SWAP"
            prop_component_name = prop[:name].sub(/^(\w)/) { $1.upcase } + "Component"
            return "{#{prop_component_name} ? <#{prop_component_name}#{props_string} /> : <#{component_name}#{props_string} />}"
          end
        end

        return "<#{component_name}#{props_string} />"
      end

      svg_content = @resolver.find_svg_for_detached(node)

      if svg_content
        styles = extract_frame_styles(node, false)
        css_rules[class_name] = styles.merge(
          "display" => "inline-flex",
          "align-items" => "center",
          "justify-content" => "center"
        )

        safe_svg = svg_content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        clean_svg = safe_svg
          .gsub(/<\?xml[^>]*\?>/, "")
          .gsub(/xmlns="[^"]*"/, "")
          .gsub(/class="/, "className=\"")
          .strip

        "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
      else
        styles = extract_frame_styles(node, false)
        css_rules[class_name] = styles
        "<div className=\"#{class_name}\" />"
      end
    end

    def generate_instance(node, root_name, class_name, css_rules, depth)
      component_id = node["componentId"]

      referenced = @resolver.components_by_node_id[component_id]
      if referenced
        component_name = to_component_name(referenced.name)
        return "<#{component_name} />"
      end

      referenced_set = @resolver.component_sets_by_node_id[component_id]
      if referenced_set
        component_name = to_component_name(referenced_set.name)
        props_string = extract_instance_override_props(node, referenced_set, root_name, css_rules, depth)
        return "<#{component_name}#{props_string} />"
      end

      variant = @resolver.variants_by_node_id[component_id]
      if variant
        component_name = to_component_name(variant.component_set.name)
        props_string = extract_instance_override_props(node, variant.component_set, root_name, css_rules, depth)
        return "<#{component_name}#{props_string} />"
      end

      comp_key = @resolver.component_key_by_node_id[component_id]
      if comp_key
        variant = @resolver.variants_by_component_key[comp_key]
        if variant
          component_name = to_component_name(variant.component_set.name)
          props_string = extract_instance_override_props(node, variant.component_set, root_name, css_rules, depth)
          return "<#{component_name}#{props_string} />"
        end
      end

      instance_name = node["name"] || "unknown"
      @resolver.track_unresolved_instance(component_id, instance_name)

      styles = extract_frame_styles(node, false)
      bbox = node["absoluteBoundingBox"] || {}
      w = bbox["width"]&.round
      h = bbox["height"]&.round
      styles["background"] = "#FF69B4"
      styles["width"] = "#{w}px" if w
      styles["height"] = "#{h}px" if h
      css_rules[class_name] = styles
      "<div className=\"#{class_name}\" title=\"Missing: #{escape_jsx(instance_name)}\" />"
    end

    def extract_instance_override_props(node, component_set, root_name = nil, css_rules = nil, depth = 0)
      component_properties = node["componentProperties"]
      return "" unless component_properties.is_a?(Hash) && component_properties.any?

      prop_definitions = component_set.prop_definitions || {}
      props_parts = []

      children_by_swap_ref = {}
      (node["children"] || []).each do |child|
        ref = child.dig("componentPropertyReferences", "mainComponent")
        children_by_swap_ref[ref] = child if ref
      end

      component_properties.each do |key, prop_data|
        prop_type = prop_data["type"]
        value = prop_data["value"]

        clean_key = key.gsub(/#[\d:]+$/, "").strip
        matching_def_key = prop_definitions.keys.find { |dk| dk.gsub(/#[\d:]+$/, "").strip == clean_key }
        definition = matching_def_key ? prop_definitions[matching_def_key] : nil

        next if definition && definition["defaultValue"].to_s == value.to_s

        prop_name = @resolver.to_prop_name(clean_key.gsub(/^[\s\u21B3]+/, "").strip)

        case prop_type
        when "VARIANT"
          props_parts << "#{prop_name}=\"#{value}\""
        when "BOOLEAN"
          props_parts << "#{prop_name}={#{value}}"
        when "INSTANCE_SWAP"
          preferred = definition&.dig("preferredValues") || []
          if preferred.empty?
            child_node = children_by_swap_ref[key]
            next unless child_node
            comp_name = @resolver.resolve_instance_component_name(child_node)
            next unless comp_name
            component_prop_name = prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
            props_parts << "#{component_prop_name}={#{comp_name}}"
          else
            next unless root_name && css_rules
            child_node = children_by_swap_ref[key]
            next unless child_node
            child_jsx = render_instance_swap_child(child_node, root_name, css_rules, depth)
            next if child_jsx.blank?
            props_parts << "#{prop_name}={#{child_jsx}}"
          end
        end
      end

      props_parts.empty? ? "" : " " + props_parts.join(" ")
    end

    def render_instance_swap_child(child_node, root_name, css_rules, depth)
      child_component_id = child_node["componentId"]
      if child_component_id
        ref_comp = @resolver.components_by_node_id[child_component_id]
        return "<#{to_component_name(ref_comp.name)} />" if ref_comp

        ref_set = @resolver.component_sets_by_node_id[child_component_id]
        if ref_set
          name = to_component_name(ref_set.name)
          child_props = extract_instance_override_props(child_node, ref_set, root_name, css_rules, depth)
          return "<#{name}#{child_props} />"
        end

        ref_variant = @resolver.variants_by_node_id[child_component_id]
        if ref_variant
          name = to_component_name(ref_variant.component_set.name)
          child_props = extract_instance_override_props(child_node, ref_variant.component_set, root_name, css_rules, depth)
          return "<#{name}#{child_props} />"
        end

        comp_key = @resolver.component_key_by_node_id[child_component_id]
        if comp_key
          ref_variant = @resolver.variants_by_component_key[comp_key]
          if ref_variant
            name = to_component_name(ref_variant.component_set.name)
            child_props = extract_instance_override_props(child_node, ref_variant.component_set, root_name, css_rules, depth)
            return "<#{name}#{child_props} />"
          end
        end
      end

      children_jsx = (child_node["children"] || []).map do |gc|
        generate_node(gc, root_name, css_rules, depth + 1)
      end.join("\n")

      return nil if children_jsx.strip.empty?

      @class_index += 1
      cls = "#{root_name.downcase.gsub(/[^a-z0-9]/, "")}-swap-#{@class_index}"
      styles = extract_frame_styles(child_node, false)
      css_rules[cls] = styles

      indent = "  " * (depth + 2)
      children_indented = children_jsx.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")
      "<div className=\"#{cls}\">#{children_indented}</div>"
    end

    private

    def next_class_index
      @class_index += 1
      @class_index
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

    # Legacy class name generation that takes root_name as first arg (matching ReactFactory's signature)
    def generate_class_name_legacy(root_name, name, is_root = false)
      if is_root
        "root"
      else
        suffix = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        suffix = "el" if suffix.empty?
        index = next_class_index
        "#{suffix}-#{index}"
      end
    end

    # --- IR-based emission helpers ---

    def emit_frame(ir, depth, is_root: false)
      class_name = generate_class_name(ir[:name], is_root)
      @css_rules[class_name] = ir[:styles]

      children_jsx = ir[:children].map do |child|
        emit_node(child, depth + 1)
      end.compact.join("\n")

      indent = "  " * (depth + 2)
      children_indented = children_jsx.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")

      data_attr = is_root ? " data-component=\"#{@component_name}\"" : ""

      if children_jsx.strip.empty?
        "<div className=\"#{class_name}\"#{data_attr} />"
      else
        "<div className=\"#{class_name}\"#{data_attr}>\n#{children_indented}\n#{"  " * (depth + 1)}</div>"
      end
    end

    def emit_text(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]

      if ir[:text_prop]
        "<span className=\"#{class_name}\">{#{ir[:text_prop]}}</span>"
      else
        escaped_text = escape_jsx(ir[:text_content] || "")
        "<span className=\"#{class_name}\">#{escaped_text}</span>"
      end
    end

    def emit_shape(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]
      "<div className=\"#{class_name}\" />"
    end

    def emit_component_ref(ir)
      if ir[:prop_overrides].any?
        props_string = ir[:prop_overrides].map { |k, v| "#{k}=#{v}" }.join(" ")
        "<#{ir[:component_name]} #{props_string} />"
      else
        "<#{ir[:component_name]} />"
      end
    end

    def emit_slot(ir)
      "{props.#{ir[:prop_name]}}"
    end

    def emit_icon_swap(ir)
      prop = ir[:prop_name]
      if ir[:style_overrides].any?
        style_pairs = ir[:style_overrides].map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
        "{#{prop} && <#{prop} style={{#{style_pairs}}} />}"
      else
        "{#{prop} && <#{prop} />}"
      end
    end

    def emit_image_swap(ir)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles] if ir[:styles].any?
      wrap_class = ir[:styles].any? ? " className=\"#{class_name}\"" : ""
      "<div#{wrap_class} style={{width: '100%', height: '100%', backgroundImage: props.#{ir[:prop_name]} ? `url(https://design-gpt.xyz/api/images/render?prompt=${encodeURIComponent(props.#{ir[:prop_name]})})` : 'none', backgroundSize: 'cover', backgroundPosition: 'center'}} />"
    end

    def emit_svg_inline(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      svg_content = ir[:svg_content].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      clean_svg = svg_content
        .gsub(/<\?xml[^>]*\?>/, "")
        .gsub(/xmlns="[^"]*"/, "")
        .strip
      @css_rules[class_name] = ir[:styles]
      "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
    end

    def emit_png_inline(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]
      "<img className=\"#{class_name}\" src={\"data:image/png;base64,#{ir[:png_data]}\"} />"
    end

    def emit_unresolved(ir, depth)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]
      "<div className=\"#{class_name}\" title=\"Missing: #{escape_jsx(ir[:instance_name])}\" />"
    end
  end
end
