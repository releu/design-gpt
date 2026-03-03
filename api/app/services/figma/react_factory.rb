module Figma
  class ReactFactory
    include Figma::StyleExtractor

    def initialize(component_library)
      @component_library = component_library
      @components_by_node_id = {}
      @component_sets_by_node_id = {}
      @variants_by_node_id = {}
      @node_id_to_component_set = {}
      @generated = {}
      @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
      @svg_assets_by_name = {}
      @inline_svgs_by_node_id = {}
      @current_props = {}
      @nested_instance_props = {}
      @nested_instance_counters = {}
      @class_index = 0
    end

    def generate_all
      log "Starting React code generation for ComponentLibrary##{@component_library.id}"

      @component_library.components.each do |component|
        @components_by_node_id[component.node_id] = component
      end

      @component_library.component_sets.includes(:variants).each do |component_set|
        @component_sets_by_node_id[component_set.node_id] = component_set
        component_set.variants.each do |variant|
          @variants_by_node_id[variant.node_id] = variant
          if variant.figma_json.present?
            collect_all_node_ids(variant.figma_json).each do |node_id|
              @node_id_to_component_set[node_id] = component_set
            end
          end
        end
      end

      log "Built lookup tables: #{@components_by_node_id.size} components, #{@component_sets_by_node_id.size} component sets, #{@variants_by_node_id.size} variants, #{@node_id_to_component_set.size} node mappings"

      build_svg_asset_cache
      log "SVG asset cache: #{@svg_assets_by_name.size} assets"

      build_inline_svg_cache
      log "Inline SVG cache: #{@inline_svgs_by_node_id.size} assets"

      component_sets = @component_library.component_sets.to_a
      log "Generating React code for #{component_sets.size} component sets..."
      component_sets.each_with_index do |component_set, idx|
        generate_component_set(component_set)
        log "  [#{idx + 1}/#{component_sets.size}] #{component_set.name}" if (idx + 1) % 10 == 0 || idx == component_sets.size - 1
      end

      components = @component_library.components.to_a
      log "Generating React code for #{components.size} standalone components..."
      components.each_with_index do |component, idx|
        generate_component(component)
        log "  [#{idx + 1}/#{components.size}] #{component.name}" if (idx + 1) % 10 == 0 || idx == components.size - 1
      end

      log "React code generation complete! Generated #{@generated.size} components"
      @generated
    end

    def log(message)
      puts "[Figma::ReactFactory] #{message}"
    end

    def generate_component_set(component_set)
      return @generated[component_set.node_id] if @generated[component_set.node_id]

      build_svg_asset_cache if @svg_assets_by_name.empty?
      build_inline_svg_cache if @inline_svgs_by_node_id.empty?
      build_node_id_cache if @node_id_to_component_set.empty?

      default_variant = component_set.default_variant
      return nil unless default_variant&.figma_json.present?

      component_name = to_component_name(component_set.name)

      normalized_name = normalize_icon_name(component_set.name)
      svg_content = @svg_assets_by_name[normalized_name]

      if svg_content
        code = generate_svg_component_code(component_name, svg_content)
      else
        prop_definitions = component_set.prop_definitions || {}
        variant_prop_names = prop_definitions.select { |_, d| d["type"] == "VARIANT" }.keys
        all_variants = component_set.variants
          .select { |v| v.figma_json.present? }
          .sort_by { |v| [v.is_default ? 0 : 1, v.id] }

        if variant_prop_names.any? && all_variants.size > 1
          code = generate_multi_variant_code(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
        else
          @class_index = 0
          @has_slot = false
          @nested_instance_counters = {}
          @nested_instance_props = {}
          @prop_definitions = prop_definitions
          @is_list_component = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")
          @rendered_list_slots = []

          node = default_variant.figma_json

          @current_props = extract_props(prop_definitions)

          collect_nested_instance_props(node)

          instances, detached_nodes = collect_instances(node)
          imports = generate_imports(instances, detached_nodes)

          css_rules = {}
          jsx = generate_node(node, component_name, css_rules, 0, true)
          css = generate_css(css_rules)

          all_props = @current_props.merge(@nested_instance_props)
          code = build_component_code(component_name, imports, css, jsx, all_props, has_slot: @has_slot)
        end
      end

      compiled_code = compile_for_browser(code, component_name, "cs_#{component_set.id}")

      @generated[component_set.node_id] = {
        name: component_name,
        code: code,
        compiled_code: compiled_code,
        node_id: component_set.node_id,
        type: :component_set
      }

      default_variant.update!(react_code: code, react_code_compiled: compiled_code)

      @generated[component_set.node_id]
    end

    def generate_component(component)
      return @generated[component.node_id] if @generated[component.node_id]

      build_svg_asset_cache if @svg_assets_by_name.empty?
      build_inline_svg_cache if @inline_svgs_by_node_id.empty?
      build_node_id_cache if @node_id_to_component_set.empty?

      figma = component.figma_json
      return nil unless figma.present?

      component_name = to_component_name(component.name)

      node = if figma["type"] == "COMPONENT_SET"
        default_variant_id = figma["defaultVariantId"]
        default_variant = (figma["children"] || []).find { |c| c["id"] == default_variant_id }
        default_variant || figma["children"]&.first || figma
      else
        figma
      end

      @class_index = 0
      @has_slot = false
      @prop_definitions = component.prop_definitions || {}
      @is_list_component = component.name.include?("#list") || component.description.to_s.include?("#list")
      @rendered_list_slots = []

      @current_props = extract_props(component.prop_definitions || {})

      instances, detached_nodes = collect_instances(node)
      imports = generate_imports(instances, detached_nodes)

      css_rules = {}
      jsx = generate_node(node, component_name, css_rules, 0, true)
      css = generate_css(css_rules)

      code = build_component_code(component_name, imports, css, jsx, @current_props, has_slot: @has_slot)

      compiled_code = compile_for_browser(code, component_name, "c_#{component.id}")

      @generated[component.node_id] = {
        name: component_name,
        code: code,
        compiled_code: compiled_code,
        node_id: component.node_id
      }

      component.update!(react_code: code, react_code_compiled: compiled_code)

      @generated[component.node_id]
    end

    private

    def next_class_index
      @class_index += 1
      @class_index
    end

    def generate_svg_component_code(component_name, svg_content)
      safe_svg = svg_content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      clean_svg = safe_svg
        .gsub(/<\?xml[^>]*\?>/, "")
        .gsub(/xmlns="[^"]*"/, "")
        .strip

      <<~CODE
        import React from 'react';

        const svg = `#{clean_svg.gsub('`', '\\`')}`;

        export function #{component_name}(props) {
          return (
            <div data-component="#{component_name}" dangerouslySetInnerHTML={{__html: svg}} {...props} />
          );
        }

        export default #{component_name};
      CODE
    end

    def extract_props(prop_definitions)
      props = {}
      return props unless prop_definitions.is_a?(Hash)

      prop_names_by_type = {}
      prop_definitions.each do |key, definition|
        prop_type = definition["type"]
        clean_name = key.gsub(/#[\d:]+$/, "").strip
        clean_name = clean_name.gsub(/^[\s↳]+/, "").strip
        prop_name = to_prop_name(clean_name)
        prop_names_by_type[prop_name] ||= []
        prop_names_by_type[prop_name] << prop_type
      end

      prop_definitions.each do |key, definition|
        prop_type = definition["type"]
        default_value = definition["defaultValue"]

        clean_name = key.gsub(/#[\d:]+$/, "").strip
        is_nested = key.start_with?("↳") || key.match?(/^[\s↳]+/)
        clean_name = clean_name.gsub(/^[\s↳]+/, "").strip

        prop_name = to_prop_name(clean_name)

        if prop_names_by_type[prop_name]&.length.to_i > 1
          if prop_type == "TEXT"
            prop_name = "#{prop_name}Content"
          end
        end

        if prop_type == "INSTANCE_SWAP" && default_value.present?
          component_set = find_component_set_by_any_node_id(default_value)
          default_value = component_set ? to_component_name(component_set.name) : nil
        end

        props[key] = {
          name: prop_name,
          type: prop_type,
          default_value: default_value,
          original_key: key
        }
      end

      props
    end

    def to_prop_name(name)
      clean_name = name.to_s.gsub(/[^\w\s-]/i, "").strip

      words = clean_name.split(/[\s_-]+/)
      return "prop" if words.empty? || words.all?(&:empty?)

      words = words.reject(&:empty?)
      return "prop" if words.empty?

      first = words.first.downcase.gsub(/[^a-z0-9]/i, "")
      rest = words[1..].map { |w| w.gsub(/[^a-z0-9]/i, "").capitalize }.join

      result = first + rest
      result = "prop#{result}" if result.match?(/^\d/)
      result.empty? ? "prop" : result
    end

    def find_prop_for_reference(reference_key)
      @current_props[reference_key] || @current_props[strip_ref_suffix(reference_key)]
    end

    # Look up a prop definition by reference key, handling Figma #nodeId suffixes.
    # The importer strips suffixes from prop_definitions keys, but figma_json
    # componentPropertyReferences still use the original suffixed keys.
    def find_prop_definition(reference_key)
      @prop_definitions[reference_key] || @prop_definitions[strip_ref_suffix(reference_key)]
    end

    def strip_ref_suffix(key)
      key.to_s.gsub(/#[\d:]+$/, "").strip
    end

    # Returns true if this INSTANCE node should be replaced with {props.children}.
    # Detection: bound to an INSTANCE_SWAP prop that has preferredValues.
    def slot_instance?(node)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return false unless ref

      defn = find_prop_definition(ref)
      defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?
    end

    # Returns true if the given componentPropertyReferences key points to an
    # INSTANCE_SWAP prop definition (used for #list detection).
    def instance_swap_ref?(ref)
      find_prop_definition(ref)&.dig("type") == "INSTANCE_SWAP"
    end

    def collect_instances(node, instances = [], detached_nodes = [])
      return [instances, detached_nodes] unless node.is_a?(Hash)

      if node["type"] == "INSTANCE" && node["componentId"]
        ref = node["componentPropertyReferences"]&.dig("mainComponent")
        is_slot = slot_instance?(node) || (@is_list_component && ref && instance_swap_ref?(ref))
        instances << node["componentId"] unless is_slot
      end

      if node["_detached"] && node["_was_instance"]
        detached_nodes << node
      end

      (node["children"] || []).each do |child|
        collect_instances(child, instances, detached_nodes)
      end

      [instances.uniq, detached_nodes]
    end

    def collect_nested_instance_props(node, parent_path = [])
      return unless node.is_a?(Hash)

      if node["_detached"] && node["_was_instance"]
        component_set = find_component_set_for_detached(node)
        if component_set
          component_type_name = to_component_name(component_set.name).downcase
          @nested_instance_counters[component_type_name] ||= 0
          @nested_instance_counters[component_type_name] += 1
          instance_index = @nested_instance_counters[component_type_name]
          instance_key = "#{component_type_name}#{instance_index}"
          node["_instance_key"] = instance_key

          prop_definitions = component_set.prop_definitions || {}

          prop_definitions.each do |key, definition|
            if definition["type"] == "TEXT"
              clean_name = key.gsub(/#[\d:]+$/, "").strip
              original_prop_name = to_prop_name(clean_name)
              default_value = definition["defaultValue"]
              text_nodes = find_text_nodes_with_reference(node, key)
              actual_value = text_nodes.first&.dig("characters") || default_value
              namespaced_prop_name = "#{instance_key}#{original_prop_name.sub(/^(\w)/) { $1.upcase }}"
              safe_value = actual_value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

              @nested_instance_props[namespaced_prop_name] = {
                name: namespaced_prop_name,
                type: "TEXT",
                default_value: safe_value,
                original_key: key,
                instance_key: instance_key,
                original_prop_name: original_prop_name
              }
            elsif definition["type"] == "INSTANCE_SWAP"
              clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s↳]+/, "")
              original_prop_name = to_prop_name(clean_name)
              original_component_name = original_prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
              namespaced_prop_name = "#{instance_key}#{original_component_name}"
              instance_nodes = find_nodes_with_main_component_reference(node, key)
              resolved_component_set = nil
              instance_nodes.each do |instance_node|
                resolved_component_set = find_component_set_for_detached(instance_node)
                break if resolved_component_set
              end
              resolved_name = resolved_component_set ? to_component_name(resolved_component_set.name) : nil

              @nested_instance_props[namespaced_prop_name] = {
                name: namespaced_prop_name,
                type: "INSTANCE_SWAP",
                default_value: resolved_name,
                original_key: key,
                instance_key: instance_key,
                original_prop_name: original_component_name
              }
            end
          end
        end
      end

      (node["children"] || []).each do |child|
        collect_nested_instance_props(child, parent_path + [node["name"]])
      end
    end

    def generate_imports(instances, detached_nodes = [])
      imports = []

      instances.each do |component_id|
        referenced = @components_by_node_id[component_id]
        if referenced
          component_name = to_component_name(referenced.name)
          imports << "import { #{component_name} } from './#{component_name}';"
          next
        end

        referenced_set = @component_sets_by_node_id[component_id]
        if referenced_set
          component_name = to_component_name(referenced_set.name)
          imports << "import { #{component_name} } from './#{component_name}';"
          next
        end

        variant = @variants_by_node_id[component_id]
        if variant
          component_name = to_component_name(variant.component_set.name)
          imports << "import { #{component_name} } from './#{component_name}';"
        end
      end

      detached_nodes.each do |node|
        component_set = find_component_set_for_detached(node)
        if component_set
          component_name = to_component_name(component_set.name)
          imports << "import { #{component_name} } from './#{component_name}';"
        end
      end

      imports.uniq.join("\n")
    end

    def generate_node(node, root_name, css_rules, depth, is_root = false)
      return "" unless node.is_a?(Hash)

      prop_refs = node["componentPropertyReferences"] || {}
      visibility_ref = prop_refs["visible"]

      if visibility_ref
        prop = find_prop_for_reference(visibility_ref)
        if prop
          if prop[:type] == "BOOLEAN"
            return "" if prop[:default_value] == false && node["visible"] == false
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

      class_name = generate_class_name(root_name, name, is_root)

      jsx = if node["_detached"] && node["_was_instance"]
        generate_detached_instance(node, root_name, class_name, css_rules, depth)
      else
        case type
        when "COMPONENT", "COMPONENT_SET", "FRAME", "GROUP"
          generate_frame(node, root_name, class_name, css_rules, depth, is_root)
        when "TEXT"
          generate_text(node, root_name, class_name, css_rules, depth)
        when *VECTOR_TYPES
          generate_shape(node, root_name, class_name, css_rules, depth)
        when "INSTANCE"
          ref = node["componentPropertyReferences"]&.dig("mainComponent")
          if @is_list_component && ref && instance_swap_ref?(ref)
            if @rendered_list_slots.include?(ref)
              ""
            else
              @rendered_list_slots << ref
              @has_slot = true
              "{props.children}"
            end
          elsif slot_instance?(node)
            @has_slot = true
            "{props.children}"
          else
            generate_instance(node, root_name, class_name, css_rules, depth)
          end
        else
          generate_frame(node, root_name, class_name, css_rules, depth, is_root)
        end
      end

      if visibility_ref
        prop = find_prop_for_reference(visibility_ref)
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

    def generate_class_name(root_name, name, is_root = false)
      if is_root
        "root"
      else
        suffix = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        suffix = "el" if suffix.empty?
        index = next_class_index
        "#{suffix}-#{index}"
      end
    end

    def generate_frame(node, root_name, class_name, css_rules, depth, is_root = false)
      styles = extract_frame_styles(node, is_root)
      css_rules[class_name] = styles

      node_id = node["id"]
      if !is_root && vector_frame?(node) && @inline_svgs_by_node_id[node_id]
        svg_content = @inline_svgs_by_node_id[node_id].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        clean_svg = svg_content
          .gsub(/<\?xml[^>]*\?>/, "")
          .gsub(/xmlns="[^"]*"/, "")
          .strip
        return "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
      end

      uses_absolute = !node["layoutMode"] && (node["children"] || []).any?

      children_jsx = (node["children"] || []).map.with_index do |child, idx|
        child_jsx = generate_node(child, root_name, css_rules, depth + 1)

        if uses_absolute && child_jsx.present?
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

    def generate_text(node, root_name, class_name, css_rules, depth)
      styles = extract_text_styles(node)
      css_rules[class_name] = styles

      text = node["characters"] || ""

      prop_refs = node["componentPropertyReferences"] || {}
      characters_ref = prop_refs["characters"]

      if characters_ref
        prop = find_prop_for_reference(characters_ref)
        if prop && prop[:type] == "TEXT"
          return "<span className=\"#{class_name}\">{#{prop[:name]}}</span>"
        end
      end

      escaped_text = escape_jsx(text)
      "<span className=\"#{class_name}\">#{escaped_text}</span>"
    end

    def generate_shape(node, root_name, class_name, css_rules, depth)
      styles = extract_shape_styles(node)
      css_rules[class_name] = styles
      "<div className=\"#{class_name}\" />"
    end

    def generate_detached_instance(node, root_name, class_name, css_rules, depth)
      original_component_id = node["_original_component_id"]
      name = node["name"] || "icon"

      prop_refs = node["componentPropertyReferences"] || {}
      main_component_ref = prop_refs["mainComponent"]

      component_set = find_component_set_for_detached(node)

      if component_set
        component_name = to_component_name(component_set.name)
        instance_key = node["_instance_key"]

        if instance_key
          props_parts = []
          prop_definitions = component_set.prop_definitions || {}

          prop_definitions.each do |key, definition|
            if definition["type"] == "TEXT"
              clean_name = key.gsub(/#[\d:]+$/, "").strip
              original_prop_name = to_prop_name(clean_name)
              namespaced_prop_name = "#{instance_key}#{original_prop_name.sub(/^(\w)/) { $1.upcase }}"
              if @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_prop_name}={#{namespaced_prop_name}}"
              end
            elsif definition["type"] == "INSTANCE_SWAP"
              clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s↳]+/, "")
              original_prop_name = to_prop_name(clean_name)
              original_component_name = original_prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
              namespaced_prop_name = "#{instance_key}#{original_component_name}"
              if @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_component_name}={#{namespaced_prop_name}}"
              end
            end
          end

          props_string = props_parts.empty? ? "" : " " + props_parts.join(" ")
        else
          overridden_props = extract_overridden_props(node, component_set)
          props_string = overridden_props.map { |k, v| "#{k}={#{v}}" }.join(" ")
          props_string = " " + props_string unless props_string.empty?
        end

        if main_component_ref
          prop = find_prop_for_reference(main_component_ref)
          if prop && prop[:type] == "INSTANCE_SWAP"
            prop_component_name = prop[:name].sub(/^(\w)/) { $1.upcase } + "Component"
            return "{#{prop_component_name} ? <#{prop_component_name}#{props_string} /> : <#{component_name}#{props_string} />}"
          end
        end

        return "<#{component_name}#{props_string} />"
      end

      svg_content = find_svg_for_detached(node)

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

    def extract_overridden_props(node, component_set)
      props = {}
      prop_definitions = component_set.prop_definitions || {}

      prop_definitions.each do |key, definition|
        if definition["type"] == "TEXT"
          clean_name = key.gsub(/#[\d:]+$/, "").strip
          prop_name = to_prop_name(clean_name)
          default_value = definition["defaultValue"]

          text_nodes = find_text_nodes_with_reference(node, key)
          text_nodes.each do |text_node|
            actual_value = text_node["characters"]
            if actual_value && actual_value != default_value
              safe_value = actual_value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
              escaped_value = safe_value.gsub('"', '\\"').gsub("\n", "\\n")
              props[prop_name] = "\"#{escaped_value}\""
            end
          end
        elsif definition["type"] == "INSTANCE_SWAP"
          clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s↳]+/, "")
          prop_name = to_prop_name(clean_name)
          prop_component_name = prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
          default_component_id = definition["defaultValue"]

          instance_nodes = find_nodes_with_main_component_reference(node, key)
          instance_nodes.each do |instance_node|
            resolved_component_set = find_component_set_for_detached(instance_node)
            if resolved_component_set
              resolved_name = to_component_name(resolved_component_set.name)
              default_component_set = find_component_set_by_any_node_id(default_component_id)
              default_name = default_component_set ? to_component_name(default_component_set.name) : nil
              if resolved_name != default_name
                props[prop_component_name] = resolved_name
              end
            end
          end
        end
      end

      props
    end

    def find_text_nodes_with_reference(node, reference_key)
      results = []
      return results unless node.is_a?(Hash)

      refs = node["componentPropertyReferences"] || {}
      if node["type"] == "TEXT" && refs["characters"] == reference_key
        results << node
      end

      (node["children"] || []).each do |child|
        results += find_text_nodes_with_reference(child, reference_key)
      end

      results
    end

    def find_all_text_nodes(node)
      results = []
      return results unless node.is_a?(Hash)

      results << node if node["type"] == "TEXT"

      (node["children"] || []).each do |child|
        results += find_all_text_nodes(child)
      end

      results
    end

    def find_nodes_with_main_component_reference(node, reference_key)
      results = []
      return results unless node.is_a?(Hash)

      refs = node["componentPropertyReferences"] || {}
      if refs["mainComponent"] == reference_key
        results << node
      end

      (node["children"] || []).each do |child|
        results += find_nodes_with_main_component_reference(child, reference_key)
      end

      results
    end

    def find_component_set_by_any_node_id(node_id)
      return nil unless node_id.present?

      cs = @component_sets_by_node_id[node_id]
      return cs if cs

      variant = @variants_by_node_id[node_id]
      return variant.component_set if variant

      @node_id_to_component_set[node_id]
    end

    def find_component_set_for_detached(node)
      original_child_ids = extract_original_child_ids(node)

      original_child_ids.each do |node_id|
        component_set = @node_id_to_component_set[node_id]
        return component_set if component_set
      end

      nil
    end

    def extract_original_child_ids(node)
      ids = []
      (node["children"] || []).each do |child|
        child_id = child["id"] || ""
        if child_id.include?(";")
          original_id = child_id.split(";").last
          ids << original_id
        end
        ids += extract_original_child_ids(child)
      end
      ids.uniq
    end

    def collect_all_node_ids(node)
      return [] unless node.is_a?(Hash)
      ids = [node["id"]].compact
      (node["children"] || []).each do |child|
        ids += collect_all_node_ids(child)
      end
      ids
    end

    def find_svg_for_detached(node)
      original_component_id = node["_original_component_id"]

      if original_component_id
        variant = @variants_by_node_id[original_component_id] || ComponentVariant.find_by(node_id: original_component_id)
        if variant
          component_set_name = normalize_icon_name(variant.component_set.name)
          return @svg_assets_by_name[component_set_name] if @svg_assets_by_name[component_set_name]
        end

        component_set = @component_sets_by_node_id[original_component_id]
        if component_set
          component_set_name = normalize_icon_name(component_set.name)
          return @svg_assets_by_name[component_set_name] if @svg_assets_by_name[component_set_name]
        end

        asset = FigmaAsset.joins(:component)
          .where(components: { node_id: original_component_id })
          .where(asset_type: "svg")
          .first
        return asset.content if asset&.content.present?

        asset = FigmaAsset.joins(:component_set)
          .where(component_sets: { node_id: original_component_id })
          .where(asset_type: "svg")
          .first
        return asset.content if asset&.content.present?

        component_set_name = lookup_component_set_name_for_variant(original_component_id)
        if component_set_name
          normalized = normalize_icon_name(component_set_name)
          return @svg_assets_by_name[normalized] if @svg_assets_by_name[normalized]
        end
      end

      icon_name = extract_icon_name_from_children(node)
      if icon_name && @svg_assets_by_name[icon_name]
        return @svg_assets_by_name[icon_name]
      end

      if icon_name
        variations = [
          icon_name,
          icon_name.gsub(/-fill$/, ""),
          icon_name.gsub(/-outline$/, ""),
          icon_name.gsub(/^icon-/, "")
        ].uniq

        variations.each do |variant_name|
          return @svg_assets_by_name[variant_name] if @svg_assets_by_name[variant_name]
        end
      end

      nil
    end

    def lookup_component_set_name_for_variant(variant_node_id)
      @figma_components_cache ||= {}

      @component_library.component_sets.select(:figma_file_key).distinct.pluck(:figma_file_key).each do |file_key|
        next if file_key.blank?

        unless @figma_components_cache[file_key]
          begin
            response = @figma.get("/v1/files/#{file_key}")
            @figma_components_cache[file_key] = {
              components: response["components"] || {},
              component_sets: response["componentSets"] || {}
            }
          rescue => e
            Rails.logger.warn("Failed to fetch Figma file #{file_key}: #{e.message}")
            @figma_components_cache[file_key] = { components: {}, component_sets: {} }
          end
        end

        cache = @figma_components_cache[file_key]
        variant_meta = cache[:components][variant_node_id]

        if variant_meta && variant_meta["componentSetId"]
          set_meta = cache[:component_sets][variant_meta["componentSetId"]]
          return set_meta["name"] if set_meta
        end
      end

      nil
    end

    def extract_icon_name_from_children(node)
      return nil unless node.is_a?(Hash)

      children = node["children"] || []

      children.each do |child|
        child_name = child["name"].to_s.downcase

        if child_name == "icon" && child["type"] == "VECTOR"
          siblings = children.select { |c| c["id"] != child["id"] }
          siblings.each do |sibling|
            sibling_name = sibling["name"].to_s.downcase
            unless ["edit", "icon", "vector"].include?(sibling_name) || sibling_name.match?(/^vector\s*\d*$/)
              return normalize_icon_name(sibling["name"])
            end
          end
        end

        if child["type"] == "BOOLEAN_OPERATION"
          bool_children = child["children"] || []
          bool_children.each do |bc|
            bc_name = bc["name"].to_s.downcase
            unless ["edit", "icon", "vector", "subtract", "union", "intersect"].include?(bc_name) || bc_name.match?(/^vector\s*\d*$/)
              return normalize_icon_name(bc["name"])
            end
          end
        end
      end

      nil
    end

    def build_inline_svg_cache
      FigmaAsset.where(component_id: nil, component_set_id: nil)
        .where(asset_type: "svg")
        .find_each do |asset|
          @inline_svgs_by_node_id[asset.node_id] = asset.content if asset.node_id.present?
        end
    end

    def build_node_id_cache
      @component_library.component_sets.includes(:variants).each do |component_set|
        @component_sets_by_node_id[component_set.node_id] = component_set
        component_set.variants.each do |variant|
          @variants_by_node_id[variant.node_id] = variant
          if variant.figma_json.present?
            collect_all_node_ids(variant.figma_json).each do |node_id|
              @node_id_to_component_set[node_id] = component_set
            end
          end
        end
      end

      @component_library.components.each do |component|
        @components_by_node_id[component.node_id] = component
      end
    end

    def build_svg_asset_cache
      FigmaAsset.joins(:component)
        .where(components: { component_library_id: @component_library.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component.name)
          @svg_assets_by_name[name] = asset.content if name.present?
        end

      FigmaAsset.joins(:component_set)
        .where(component_sets: { component_library_id: @component_library.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component_set.name)
          @svg_assets_by_name[name] = asset.content if name.present?
        end
    end

    def generate_instance(node, root_name, class_name, css_rules, depth)
      component_id = node["componentId"]

      referenced = @components_by_node_id[component_id]
      if referenced
        component_name = to_component_name(referenced.name)
        return "<#{component_name} />"
      end

      referenced_set = @component_sets_by_node_id[component_id]
      if referenced_set
        component_name = to_component_name(referenced_set.name)
        return "<#{component_name} />"
      end

      variant = @variants_by_node_id[component_id]
      if variant
        component_name = to_component_name(variant.component_set.name)
        return "<#{component_name} />"
      end

      styles = extract_frame_styles(node, false)
      css_rules[class_name] = styles

      children_jsx = (node["children"] || []).map do |child|
        generate_node(child, root_name, css_rules, depth + 1)
      end.join("\n")

      if children_jsx.strip.empty?
        "<div className=\"#{class_name}\" />"
      else
        indent = "  " * (depth + 2)
        children_indented = children_jsx.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")
        "<div className=\"#{class_name}\">\n#{children_indented}\n#{"  " * (depth + 1)}</div>"
      end
    end

    def compile_for_browser(react_code, component_name, component_id)
      return "var #{component_name} = function() { return React.createElement('div', null, 'No code generated'); }" if react_code.blank?

      code = react_code.dup

      styles_var = "styles_#{component_id}"
      code = code.gsub(/const styles = /, "const #{styles_var} = ")
      code = code.gsub(/\{styles\}/, "{#{styles_var}}")

      svg_var = "svg_#{component_id}"
      code = code.gsub(/const svg = /, "const #{svg_var} = ")
      code = code.gsub(/\{__html: svg\}/, "{__html: #{svg_var}}")

      # Namespace internal variant functions: Button__v0 → Button_cs_42__v0
      code = code.gsub(/\b#{Regexp.escape(component_name)}__v(\d+)\b/) { "#{component_name}_#{component_id}__v#{$1}" }

      code = code.gsub(/^import [^\n]+\n/, "")
      code = code.gsub(/^export default [^\n]+\n?/, "")
      code = code.gsub(/^export /, "")

      begin
        compiled = Figma::JsxCompiler.compile(code)
        compiled = compiled.gsub(/^function (\w+)\(/, 'var \1 = function(')
        compiled.strip
      rescue Figma::JsxCompiler::CompilationError => e
        Rails.logger.error("JSX compilation failed for #{component_name}: #{e.message}")
        "var #{component_name} = function() { return React.createElement('div', {style: {color: 'red'}}, 'Compilation error: #{e.message.gsub("'", "\\\\'")}'); }"
      end
    end

    def generate_multi_variant_code(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
      variant_entries = []
      all_imports = []

      all_variants.each_with_index do |variant, idx|
        # Reset per-variant state
        @class_index = 0
        @has_slot = false
        @nested_instance_counters = {}
        @nested_instance_props = {}
        @prop_definitions = prop_definitions
        @is_list_component = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")
        @rendered_list_slots = []

        node = variant.figma_json
        scope_id = "#{component_name.downcase.gsub(/[^a-z0-9]/, "")}v#{idx}"

        @current_props = extract_props(prop_definitions)

        collect_nested_instance_props(node)

        instances, detached_nodes = collect_instances(node)
        imports = generate_imports(instances, detached_nodes)
        all_imports << imports if imports.present?

        css_rules = {}
        jsx = generate_node(node, component_name, css_rules, 0, true)
        css = generate_css(css_rules)

        # Scope CSS and JSX with per-variant scope_id
        scoped_css = css.gsub(/^\.([a-z0-9_-]+)/i) { ".#{scope_id}-#{$1}" }
        scoped_jsx = jsx.gsub(/className="([^"]+)"/) { "className=\"#{scope_id}-#{$1}\"" }

        # Add variant-specific BEM classes to the root element so that every
        # variant value produces a detectable DOM difference, even when the
        # visual structure is otherwise identical (e.g. styling-only variants).
        # Convention: ComponentName__propName_value  (e.g. Button__size_m)
        variant_classes = variant_prop_names.filter_map do |prop_key|
          clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
          prop_css = clean_key.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_]/, "")
          val = variant.variant_properties[clean_key.downcase]
          next nil if val.blank?
          val_css = val.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_]/, "")
          "#{component_name}__#{prop_css}_#{val_css}"
        end.join(" ")

        if variant_classes.present?
          scoped_jsx = scoped_jsx.sub(
            /className="(#{Regexp.escape(scope_id)}-root)"/,
            "className=\"\\1 #{variant_classes}\""
          )
        end

        # Collect non-VARIANT props for this variant's function destructuring
        non_variant_props = @current_props.merge(@nested_instance_props).reject { |_, p| p[:type] == "VARIANT" }

        variant_entries << {
          index: idx,
          func_name: "#{component_name}__v#{idx}",
          css: scoped_css,
          jsx: scoped_jsx,
          variant_properties: variant.variant_properties,
          props: non_variant_props,
          has_slot: @has_slot,
          is_default: variant.is_default
        }
      end

      build_variant_component_code(component_name, all_imports, variant_entries, variant_prop_names, prop_definitions)
    end

    def build_variant_component_code(component_name, all_imports, variant_entries, variant_prop_names, prop_definitions)
      # Deduplicated imports
      imports_section = all_imports.flat_map { |i| i.split("\n") }.uniq.join("\n")
      imports_section = imports_section.present? ? "#{imports_section}\n" : ""

      # Combined styles from all variants
      combined_css = variant_entries.map { |e| e[:css] }.join("\n")

      # Internal variant functions
      variant_functions = variant_entries.map do |entry|
        props_destructuring = generate_props_destructuring(entry[:props])
        <<~FUNC.chomp
          function #{entry[:func_name]}(#{props_destructuring}) {
            return (#{entry[:jsx]});
          }
        FUNC
      end.join("\n\n")

      # Dispatcher
      dispatcher_props = generate_variant_props_destructuring(variant_prop_names, prop_definitions, variant_entries)
      dispatch_chain = generate_variant_dispatch(component_name, variant_entries, variant_prop_names, prop_definitions)

      <<~CODE
        import React from 'react';
        #{imports_section}
        const styles = `
        #{combined_css}
        `;

        #{variant_functions}

        export function #{component_name}(#{dispatcher_props}) {
        #{dispatch_chain}
        }

        export default #{component_name};
      CODE
    end

    def generate_variant_dispatch(component_name, variant_entries, variant_prop_names, prop_definitions)
      lines = []
      default_entry = variant_entries.find { |e| e[:is_default] } || variant_entries.first

      variant_entries.each do |entry|
        conditions = variant_prop_names.map do |prop_key|
          prop_name = to_prop_name(prop_key.gsub(/#[\d:]+$/, "").strip)
          value = entry[:variant_properties][prop_key.gsub(/#[\d:]+$/, "").strip.downcase]
          next nil unless value
          "#{prop_name} === \"#{value}\""
        end.compact

        next if conditions.empty?

        lines << "  if (#{conditions.join(' && ')}) return <><style>{styles}</style><#{entry[:func_name]} {...props} /></>;"
      end

      # Fallback to default variant
      lines << "  return <><style>{styles}</style><#{default_entry[:func_name]} {...props} /></>;"
      lines.join("\n")
    end

    def generate_variant_props_destructuring(variant_prop_names, prop_definitions, variant_entries)
      defaults = variant_prop_names.map do |prop_key|
        clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
        prop_name = to_prop_name(clean_key)
        default_value = prop_definitions[prop_key]&.dig("defaultValue") || variant_entries.first[:variant_properties][clean_key.downcase]
        "#{prop_name} = \"#{default_value}\""
      end

      "{ #{defaults.join(', ')}, ...props }"
    end

    def build_component_code(component_name, imports, css, jsx, props = {}, has_slot: false)
      imports_section = imports.present? ? "#{imports}\n" : ""
      scope_id = component_name.downcase.gsub(/[^a-z0-9]/, "")

      scoped_css = css.gsub(/^\.([a-z0-9_-]+)/i) { ".#{scope_id}-#{$1}" }
      scoped_jsx = jsx.gsub(/className="([^"]+)"/) { "className=\"#{scope_id}-#{$1}\"" }

      props_with_defaults = generate_props_destructuring(props)

      children_line = ""

      <<~CODE
        import React from 'react';
        #{imports_section}
        const styles = `
        #{scoped_css}
        `;

        export function #{component_name}(#{props_with_defaults}) {
          return (
            <>
              <style>{styles}</style>
              #{scoped_jsx}#{children_line}
            </>
          );
        }

        export default #{component_name};
      CODE
    end

    def generate_props_destructuring(props)
      return "props" if props.empty?

      usable_props = props.values.select { |p| %w[TEXT BOOLEAN INSTANCE_SWAP].include?(p[:type]) }
      return "props" if usable_props.empty?

      defaults = usable_props.map do |prop|
        default = case prop[:type]
        when "TEXT"
          escaped_default = prop[:default_value].to_s.gsub('"', '\\"').gsub("\n", "\\n")
          "\"#{escaped_default}\""
        when "BOOLEAN"
          prop[:default_value].to_s
        when "INSTANCE_SWAP"
          prop[:default_value] || "null"
        else
          "undefined"
        end

        if prop[:instance_key]
          "#{prop[:name]} = #{default}"
        elsif prop[:type] == "INSTANCE_SWAP"
          prop_name = prop[:name].sub(/^(\w)/) { $1.upcase } + "Component"
          "#{prop_name} = #{default}"
        else
          "#{prop[:name]} = #{default}"
        end
      end

      "{ #{defaults.join(', ')}, ...props }"
    end
  end
end
