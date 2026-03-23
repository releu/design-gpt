module Figma
  class ReactFactory
    include Figma::StyleExtractor

    def initialize(figma_file)
      @figma_file = figma_file
      @components_by_node_id = {}
      @component_sets_by_node_id = {}
      @variants_by_node_id = {}
      @node_id_to_component_set = {}
      @generated = {}
      @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
      @svg_assets_by_name = {}
      @inline_svgs_by_node_id = {}
      @inline_pngs_by_node_id = {}
      @current_props = {}
      @nested_instance_props = {}
      @nested_instance_counters = {}
      @class_index = 0
      @image_refs = nil
      @pending_compilations = []
      @pending_variant_compilations = []
      @batch_mode = false
      @unresolved_instances = Hash.new { |h, k| h[k] = Set.new }  # owner_node_id -> Set of instance names
      @current_owner_node_id = nil  # tracks which component set/component we're generating for
    end

    def generate_all
      @batch_mode = true
      log "Starting React code generation for ComponentLibrary##{@figma_file.id}"

      @figma_file.components.each do |component|
        @components_by_node_id[component.node_id] = component
      end

      @figma_file.component_sets.includes(:variants).each do |component_set|
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

      component_sets = @figma_file.component_sets.to_a
      log "Generating React code for #{component_sets.size} component sets..."
      component_sets.each_with_index do |component_set, idx|
        @current_owner_node_id = component_set.node_id
        generate_component_set(component_set)
        log "  [#{idx + 1}/#{component_sets.size}] #{component_set.name}" if (idx + 1) % 10 == 0 || idx == component_sets.size - 1
      end

      components = @figma_file.components.to_a
      log "Generating React code for #{components.size} standalone components..."
      components.each_with_index do |component, idx|
        @current_owner_node_id = component.node_id
        generate_component(component)
        log "  [#{idx + 1}/#{components.size}] #{component.name}" if (idx + 1) % 10 == 0 || idx == components.size - 1
      end

      batch_compile_and_persist
      save_unresolved_warnings

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

      if component_set.is_image
        code = generate_image_component_code(component_name)
        compiled_code = defer_or_compile(code, component_name, "cs_#{component_set.id}", default_variant)
        @generated[component_set.node_id] = { name: component_name, code: code, compiled_code: compiled_code, node_id: component_set.node_id, type: :component_set }
        return @generated[component_set.node_id]
      end

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
          # Multi-variant: per-variant compilation handled inside, no full blob
          code = generate_multi_variant_code(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
          compiled_code = nil # per-variant code stored on each variant record
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
          @slot_map = build_slot_map(node, prop_definitions)

          collect_nested_instance_props(node)

          instances, detached_nodes = collect_instances(node)
          imports = generate_imports(instances, detached_nodes)

          css_rules = {}
          jsx = generate_node(node, component_name, css_rules, 0, true)
          css = generate_css(css_rules)

          all_props = @current_props.merge(@nested_instance_props)
          code = build_component_code(component_name, imports, css, jsx, all_props, has_slot: @has_slot)
          compiled_code = defer_or_compile(code, component_name, "cs_#{component_set.id}", default_variant)
        end
      end

      @generated[component_set.node_id] = {
        name: component_name,
        code: code,
        compiled_code: compiled_code,
        node_id: component_set.node_id,
        type: :component_set
      }

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

      if component.is_image
        code = generate_image_component_code(component_name)
        compiled_code = defer_or_compile(code, component_name, "c_#{component.id}", component)
        @generated[component.node_id] = { name: component_name, code: code, compiled_code: compiled_code, node_id: component.node_id }
        return @generated[component.node_id]
      end

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
      @slot_map = build_slot_map(node, @prop_definitions)

      instances, detached_nodes = collect_instances(node)
      imports = generate_imports(instances, detached_nodes)

      css_rules = {}
      jsx = generate_node(node, component_name, css_rules, 0, true)
      css = generate_css(css_rules)

      code = build_component_code(component_name, imports, css, jsx, @current_props, has_slot: @has_slot)

      compiled_code = defer_or_compile(code, component_name, "c_#{component.id}", component)

      @generated[component.node_id] = {
        name: component_name,
        code: code,
        compiled_code: compiled_code,
        node_id: component.node_id
      }

      @generated[component.node_id]
    end

    private

    def next_class_index
      @class_index += 1
      @class_index
    end

    def generate_image_component_code(component_name)
      <<~CODE
        import React from 'react';

        export function #{component_name}({ prompt, ...props }) {
          const src = prompt
            ? `https://design-gpt.xyz/api/images/render?prompt=${encodeURIComponent(prompt)}`
            : '';
          return (
            <div
              data-component="#{component_name}"
              style={{
                width: '100%', height: '100%',
                backgroundImage: src ? `url(${src})` : 'none',
                backgroundSize: 'cover', backgroundPosition: 'center',
              }}
              {...props}
            />
          );
        }

        export default #{component_name};
      CODE
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

        if prop_type == "INSTANCE_SWAP"
          preferred = definition["preferredValues"] || []
          if preferred.any? && preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
            # Image INSTANCE_SWAP — treat as TEXT prop (prompt string)
            prop_type = "TEXT"
            default_value = ""
          elsif default_value.present?
            component_set = find_component_set_by_any_node_id(default_value)
            default_value = component_set ? to_component_name(component_set.name) : nil
          end
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

      # Already valid camelCase: starts with lowercase, only alphanumeric
      return clean_name if clean_name.match?(/\A[a-z][a-zA-Z0-9]*\z/)

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

    # Returns true if this INSTANCE node should be replaced with slot content.
    # Detection: bound to an INSTANCE_SWAP prop that has preferredValues.
    def slot_instance?(node)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return false unless ref
      return false if image_swap_instance?(node)

      defn = find_prop_definition(ref)
      defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?
    end

    # Returns true if this INSTANCE node is bound to an INSTANCE_SWAP prop
    # whose preferredValues all point to #image components.
    def image_swap_instance?(node)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return false unless ref

      defn = find_prop_definition(ref)
      return false unless defn&.dig("type") == "INSTANCE_SWAP"

      preferred = defn["preferredValues"] || []
      preferred.any? && preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
    end

    def image_component_keys
      @image_component_keys ||= begin
        keys = Set.new
        @figma_file.component_sets.select(&:is_image).each do |cs|
          keys << cs.component_key if cs.component_key
          cs.variants.each { |v| keys << v.component_key if v.component_key }
        end
        @figma_file.components.select(&:is_image).each do |c|
          keys << c.component_key if c.component_key
        end
        keys
      end
    end

    # Pre-scan the component tree to build a map of node IDs to slot prop names.
    # Used to emit {props.children} for single-slot or {props.slotName} for multi-slot.
    def build_slot_map(node, prop_definitions)
      entries = []

      # Collect SLOT and INSTANCE_SWAP slot nodes
      walk = ->(n) do
        return unless n.is_a?(Hash)
        if n["type"] == "SLOT"
          ref = n.dig("componentPropertyReferences", "slotContentId")
          entries << { ref: ref, node_id: n["id"] } if ref
          # Don't recurse into SLOT children — they are default content
          # belonging to nested components, not slots of this component.
          next
        elsif n["type"] == "INSTANCE"
          ref = n.dig("componentPropertyReferences", "mainComponent")
          if ref
            defn = prop_definitions[ref] || prop_definitions[strip_ref_suffix(ref)]
            if defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?
              # Skip INSTANCE_SWAP props that point to #image components
              preferred = defn["preferredValues"] || []
              unless preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
                entries << { ref: ref, node_id: n["id"] }
              end
            end
          end
          # Don't recurse into INSTANCE children — their slots belong
          # to the nested component, not to this one.
          next
        end
        (n["children"] || []).each { |c| walk.call(c) }
      end
      walk.call(node)

      # Deduplicate by ref key — same ref = same logical slot
      unique_refs = entries.map { |e| strip_ref_suffix(e[:ref]) }.uniq

      map = {}
      entries.each do |e|
        name = to_prop_name(strip_ref_suffix(e[:ref]))
        map[e[:node_id]] = name
      end
      map
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
          # Boolean-controlled nodes are always generated; visibility is
          # handled at runtime via the {prop && (...)} wrapper (see below).
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
        when "SLOT"
          @has_slot = true
          slot_name = @slot_map[node["id"]] || "children"
          if node["layoutMode"]
            styles = extract_frame_styles(node, false)
            css_rules[class_name] = styles
            "<div className=\"#{class_name}\">{props.#{slot_name}}</div>"
          else
            "{props.#{slot_name}}"
          end
        when "INSTANCE"
          ref = node["componentPropertyReferences"]&.dig("mainComponent")
          if @is_list_component && ref && instance_swap_ref?(ref)
            if @rendered_list_slots.include?(ref)
              ""
            else
              @rendered_list_slots << ref
              @has_slot = true
              slot_name = @slot_map[node["id"]] || "children"
              "{props.#{slot_name}}"
            end
          elsif image_swap_instance?(node)
            ref = node["componentPropertyReferences"]["mainComponent"]
            prop_name = to_prop_name(strip_ref_suffix(ref))
            styles = extract_frame_styles(node, false) rescue {}
            css_rules[class_name] = styles if styles.any?
            wrap_class = styles.any? ? " className=\"#{class_name}\"" : ""
            "<div#{wrap_class} style={{width: '100%', height: '100%', backgroundImage: props.#{prop_name} ? `url(https://design-gpt.xyz/api/images/render?prompt=${encodeURIComponent(props.#{prop_name})})` : 'none', backgroundSize: 'cover', backgroundPosition: 'center'}} />"
          elsif slot_instance?(node)
            @has_slot = true
            slot_name = @slot_map[node["id"]] || "children"
            "{props.#{slot_name}}"
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
      if !is_root && @inline_pngs_by_node_id[node_id]
        return "<img className=\"#{class_name}\" src={\"data:image/png;base64,#{@inline_pngs_by_node_id[node_id]}\"} />"
      end
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

      node_id = node["id"]
      if @inline_pngs_by_node_id[node_id]
        css_rules[class_name] = styles
        return "<img className=\"#{class_name}\" src={\"data:image/png;base64,#{@inline_pngs_by_node_id[node_id]}\"} />"
      end
      if @inline_svgs_by_node_id[node_id]
        svg_content = @inline_svgs_by_node_id[node_id].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
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

      @figma_file.component_sets.select(:figma_file_key).distinct.pluck(:figma_file_key).each do |file_key|
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
      component_ids = @figma_file.components.pluck(:id)
      component_set_ids = @figma_file.component_sets.pluck(:id)

      FigmaAsset.where(asset_type: %w[svg png])
        .where("node_id IS NOT NULL")
        .where(
          "component_id IN (?) OR component_set_id IN (?) OR (component_id IS NULL AND component_set_id IS NULL)",
          component_ids, component_set_ids
        )
        .find_each do |asset|
          if asset.asset_type == "png"
            @inline_pngs_by_node_id[asset.node_id] = asset.content
          else
            @inline_svgs_by_node_id[asset.node_id] = asset.content
          end
        end
    end

    def build_node_id_cache
      @figma_file.component_sets.includes(:variants).each do |component_set|
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

      @figma_file.components.each do |component|
        @components_by_node_id[component.node_id] = component
      end
    end

    def build_svg_asset_cache
      FigmaAsset.joins(:component)
        .where(components: { figma_file_id: @figma_file.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component.name)
          @svg_assets_by_name[name] = asset.content if name.present?
        end

      FigmaAsset.joins(:component_set)
        .where(component_sets: { figma_file_id: @figma_file.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component_set.name)
          @svg_assets_by_name[name] = asset.content if name.present?
        end
    end

    def save_unresolved_warnings
      return if @unresolved_instances.empty?

      @unresolved_instances.each do |owner_node_id, instance_names|
        names = instance_names.to_a.sort
        warning = "Unresolved external components: #{names.join(', ')}. Add their source Figma file to the design system."

        cs = @figma_file.component_sets.find_by(node_id: owner_node_id)
        if cs
          cs.update!(validation_warnings: (cs.validation_warnings || []) + [warning])
          next
        end

        comp = @figma_file.components.find_by(node_id: owner_node_id)
        comp&.update!(validation_warnings: (comp.validation_warnings || []) + [warning])
      end

      log "Added unresolved instance warnings to #{@unresolved_instances.size} components"
    end

    def track_unresolved_instance(component_id, instance_name)
      return unless @current_owner_node_id
      @unresolved_instances[@current_owner_node_id] << instance_name
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
        props_string = extract_instance_override_props(node, referenced_set, root_name, css_rules, depth)
        return "<#{component_name}#{props_string} />"
      end

      variant = @variants_by_node_id[component_id]
      if variant
        component_name = to_component_name(variant.component_set.name)
        props_string = extract_instance_override_props(node, variant.component_set, root_name, css_rules, depth)
        return "<#{component_name}#{props_string} />"
      end

      # Unresolved instance — render a pink placeholder and track the warning
      instance_name = node["name"] || "unknown"
      track_unresolved_instance(component_id, instance_name)

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

      # Build a map from INSTANCE_SWAP prop key to child node for rendering
      children_by_swap_ref = {}
      (node["children"] || []).each do |child|
        ref = child.dig("componentPropertyReferences", "mainComponent")
        children_by_swap_ref[ref] = child if ref
      end

      component_properties.each do |key, prop_data|
        prop_type = prop_data["type"]
        value = prop_data["value"]

        # Find matching prop definition (strip #N:M suffixes for matching)
        clean_key = key.gsub(/#[\d:]+$/, "").strip
        matching_def_key = prop_definitions.keys.find { |dk| dk.gsub(/#[\d:]+$/, "").strip == clean_key }
        definition = matching_def_key ? prop_definitions[matching_def_key] : nil

        # Skip if value matches default
        next if definition && definition["defaultValue"].to_s == value.to_s

        prop_name = to_prop_name(clean_key.gsub(/^[\s↳]+/, "").strip)

        case prop_type
        when "VARIANT"
          props_parts << "#{prop_name}=\"#{value}\""
        when "BOOLEAN"
          props_parts << "#{prop_name}={#{value}}"
        when "INSTANCE_SWAP"
          next unless root_name && css_rules
          # Find the child node that corresponds to this INSTANCE_SWAP prop
          child_node = children_by_swap_ref[key]
          next unless child_node
          child_jsx = render_instance_swap_child(child_node, root_name, css_rules, depth)
          next if child_jsx.blank?
          props_parts << "#{prop_name}={#{child_jsx}}"
        end
      end

      props_parts.empty? ? "" : " " + props_parts.join(" ")
    end

    # Render an INSTANCE_SWAP child node as inline JSX.
    # If the child resolves to a known component, use it; otherwise render as detached.
    def render_instance_swap_child(child_node, root_name, css_rules, depth)
      child_component_id = child_node["componentId"]
      if child_component_id
        ref_comp = @components_by_node_id[child_component_id]
        return "<#{to_component_name(ref_comp.name)} />" if ref_comp

        ref_set = @component_sets_by_node_id[child_component_id]
        if ref_set
          name = to_component_name(ref_set.name)
          child_props = extract_instance_override_props(child_node, ref_set, root_name, css_rules, depth)
          return "<#{name}#{child_props} />"
        end

        ref_variant = @variants_by_node_id[child_component_id]
        if ref_variant
          name = to_component_name(ref_variant.component_set.name)
          child_props = extract_instance_override_props(child_node, ref_variant.component_set, root_name, css_rules, depth)
          return "<#{name}#{child_props} />"
        end
      end

      # Detached: render children inline
      children_jsx = (child_node["children"] || []).map do |gc|
        generate_node(gc, root_name, css_rules, depth + 1)
      end.join("\n")

      return nil if children_jsx.strip.empty?

      @class_index ||= 0
      @class_index += 1
      cls = "#{root_name.downcase.gsub(/[^a-z0-9]/, "")}-swap-#{@class_index}"
      styles = extract_frame_styles(child_node, false)
      css_rules[cls] = styles

      indent = "  " * (depth + 2)
      children_indented = children_jsx.lines.map { |l| "#{indent}#{l.rstrip}" }.join("\n")
      "<div className=\"#{cls}\">#{children_indented}</div>"
    end

    def add_fills(styles, fills)
      @current_image_fill = nil
      super
      if @current_image_fill
        scale_mode = @current_image_fill["scaleMode"] || "FILL"
        case scale_mode
        when "FILL"
          styles["background-size"] = "cover"
          styles["background-position"] = "center"
        when "FIT"
          styles["background-size"] = "contain"
          styles["background-position"] = "center"
          styles["background-repeat"] = "no-repeat"
        when "STRETCH"
          styles["background-size"] = "100% 100%"
        end
      end
    end

    def handle_image_fill(fill)
      image_ref = fill["imageRef"]
      return nil unless image_ref

      load_image_refs if @image_refs.nil?

      url = @image_refs[image_ref]
      return "#e0e0e0" unless url

      @current_image_fill = fill
      "url(#{url})"
    end

    def load_image_refs
      @image_refs = {}
      return unless @figma_file.figma_file_key.present?

      response = @figma.get("/v1/files/#{@figma_file.figma_file_key}/images")
      @image_refs = response.dig("meta", "images") || {}
    rescue => e
      log "Warning: could not fetch image fills: #{e.message}"
      @image_refs = {}
    end

    def compile_for_browser(react_code, component_name, component_id, scope_id: nil)
      return "var #{component_name} = function() { return React.createElement('div', null, 'No code generated'); }" if react_code.blank?

      preprocessed = preprocess_for_browser(react_code, component_name, component_id, scope_id: scope_id)

      begin
        compiled = Figma::JsxCompiler.compile(preprocessed)
        postprocess_compiled(compiled)
      rescue Figma::JsxCompiler::CompilationError => e
        Rails.logger.error("JSX compilation failed for #{component_name}: #{e.message}")
        "var #{component_name} = function() { return React.createElement('div', {style: {color: 'red'}}, 'Compilation error: #{e.message.gsub("'", "\\\\'")}'); }"
      end
    end

    # In batch mode, defer compilation to batch_compile_and_persist; otherwise compile inline.
    # Saves react_code immediately; compiled code is persisted either inline or in batch.
    def defer_or_compile(code, component_name, component_id, record)
      record.update!(react_code: code)
      if @batch_mode
        @pending_compilations << { key: component_id, name: component_name, code: code, record: record }
        nil # compiled_code will be set in batch_compile_and_persist
      else
        compiled = compile_for_browser(code, component_name, component_id)
        record.update!(react_code_compiled: compiled)
        compiled
      end
    end

    # Preprocessing: variable namespacing, import stripping — everything before esbuild
    # scope_id: unique per snippet (for variable names like styles_X, svg_X)
    # component_id: shared across variants (for function names like Button_cs_42__v0)
    def preprocess_for_browser(react_code, component_name, component_id, scope_id: nil)
      scope_id ||= component_id
      code = react_code.dup

      styles_var = "styles_#{scope_id}"
      code = code.gsub(/const styles = /, "const #{styles_var} = ")
      code = code.gsub(/\{styles\}/, "{#{styles_var}}")

      svg_var = "svg_#{scope_id}"
      code = code.gsub(/const svg = /, "const #{svg_var} = ")
      code = code.gsub(/\{__html: svg\}/, "{__html: #{svg_var}}")

      # Namespace internal variant functions: Button__v0 → Button_cs_42__v0
      code = code.gsub(/\b#{Regexp.escape(component_name)}__v(\d+)\b/) { "#{component_name}_#{component_id}__v#{$1}" }

      code = code.gsub(/^import [^\n]+\n/, "")
      code = code.gsub(/^export default [^\n]+\n?/, "")
      code = code.gsub(/^export /, "")

      code
    end

    # Post-processing: convert function declarations to var assignments
    def postprocess_compiled(compiled)
      compiled = compiled.gsub(/^function (\w+)\(/, 'var \1 = function(')
      compiled.strip
    end

    # Batch-compile all pending snippets in a single esbuild invocation, then persist
    def batch_compile_and_persist
      return if @pending_compilations.empty? && @pending_variant_compilations.empty?

      log "Batch-compiling #{@pending_compilations.size} components + #{@pending_variant_compilations.size} variants..."

      # Preprocess all component snippets
      snippets = @pending_compilations.map do |entry|
        if entry[:code].blank?
          entry[:compiled] = "var #{entry[:name]} = function() { return React.createElement('div', null, 'No code generated'); }"
          nil
        else
          preprocessed = preprocess_for_browser(entry[:code], entry[:name], entry[:key])
          { key: entry[:key], code: preprocessed }
        end
      end.compact

      # Preprocess per-variant snippets (use unique key for variable scope,
      # but shared component_id for function names to match dispatcher)
      variant_snippets = @pending_variant_compilations.map do |entry|
        preprocessed = preprocess_for_browser(entry[:code], entry[:component_name], entry[:component_id], scope_id: entry[:key])
        { key: entry[:key], code: preprocessed }
      end

      # Single esbuild invocation for all
      compiled_map = Figma::JsxCompiler.compile_batch(snippets + variant_snippets)

      # Post-process and persist per-variant compilations FIRST
      @pending_variant_compilations.each do |entry|
        raw = compiled_map[entry[:key]]
        if raw
          compiled = postprocess_compiled(raw)
          entry[:record].update!(react_code_compiled: compiled)
        else
          Rails.logger.error("Batch variant compilation missing output for #{entry[:name]}")
        end
      end

      # Post-process and persist full-blob component compilations SECOND
      # (overwrites default variant's react_code_compiled with the full blob)
      @pending_compilations.each do |entry|
        compiled = entry[:compiled] # pre-set for blank code entries
        unless compiled
          raw = compiled_map[entry[:key]]
          compiled = if raw
            postprocess_compiled(raw)
          else
            Rails.logger.error("Batch compilation missing output for #{entry[:name]}")
            "var #{entry[:name]} = function() { return React.createElement('div', {style: {color: 'red'}}, 'Compilation error'); }"
          end
        end

        entry[:record].update!(react_code_compiled: compiled)

        # Update @generated with compiled_code
        gen = @generated.values.find { |g| g[:name] == entry[:name] }
        gen[:compiled_code] = compiled if gen
      end

      log "Batch compilation complete"
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
        @slot_map = build_slot_map(node, prop_definitions)

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
          is_default: variant.is_default,
          variant_record: variant,
          imports: imports
        }
      end

      # Build per-variant self-contained snippets for selective loading.
      # For the default variant, store in react_code (source) since
      # react_code_compiled will hold the full blob from defer_or_compile.
      component_id = "cs_#{component_set.id}"
      variant_entries.each do |entry|
        imports_section = entry[:imports].present? ? "#{entry[:imports]}\n" : ""
        per_variant_code = <<~CODE
          import React from 'react';
          #{imports_section}
          const styles = `
          #{entry[:css]}
          `;

          export function #{entry[:func_name]}(#{generate_props_destructuring(entry[:props])}) {
            return (
              <>
                <style>{styles}</style>
                #{entry[:jsx]}
              </>
            );
          }
        CODE

        if @batch_mode
          @pending_variant_compilations << {
            key: "#{component_id}_v#{entry[:index]}",
            name: entry[:func_name],
            code: per_variant_code,
            record: entry[:variant_record],
            component_name: component_name,
            component_id: component_id
          }
        else
          compiled = compile_for_browser(per_variant_code, component_name, component_id, scope_id: "#{component_id}_v#{entry[:index]}")
          entry[:variant_record].update!(react_code_compiled: compiled)
        end
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
