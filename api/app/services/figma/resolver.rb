# Figma JSON → IR resolution logic.
# Accepts pre-built lookup tables and resolves Figma nodes into IR hashes (see Figma::IR).
# Does not query ActiveRecord — all DB access is done by ReactFactory.build_lookup_data.
module Figma
  class Resolver
    include Figma::StyleExtractor

    attr_reader :components_by_node_id, :component_sets_by_node_id,
                :variants_by_node_id, :node_id_to_component_set,
                :component_key_by_node_id, :variants_by_component_key,
                :svg_assets_by_name, :inline_svgs_by_node_id, :inline_pngs_by_node_id,
                :unresolved_instances

    def initialize(lookup_data, figma_client: nil)
      @figma = figma_client
      @components_by_node_id      = lookup_data[:components_by_node_id]      || {}
      @component_sets_by_node_id  = lookup_data[:component_sets_by_node_id]  || {}
      @variants_by_node_id        = lookup_data[:variants_by_node_id]        || {}
      @node_id_to_component_set   = lookup_data[:node_id_to_component_set]   || {}
      @component_key_by_node_id   = lookup_data[:component_key_by_node_id]   || {}
      @variants_by_component_key  = lookup_data[:variants_by_component_key]  || {}
      @svg_assets_by_name         = lookup_data[:svg_assets_by_name]         || {}
      @inline_svgs_by_node_id     = lookup_data[:inline_svgs_by_node_id]     || {}
      @inline_pngs_by_node_id     = lookup_data[:inline_pngs_by_node_id]    || {}
      @image_component_keys       = lookup_data[:image_component_keys]       || Set.new
      @figma_file_keys            = lookup_data[:figma_file_keys]            || Set.new
      @unresolved_instances = Hash.new { |h, k| h[k] = Set.new }
      @current_owner_node_id = nil
      @image_refs = nil
      @slot_map = {}
      @has_slot_during_resolve = false
    end

    attr_accessor :current_owner_node_id

    def track_unresolved_instance(component_id, instance_name)
      return unless @current_owner_node_id
      @unresolved_instances[@current_owner_node_id] << instance_name
    end

    def image_component_keys
      @image_component_keys
    end

    # Mutable state set by the caller (ReactFactory) before resolution
    attr_accessor :current_props, :prop_definitions, :nested_instance_props,
                  :nested_instance_counters, :is_list_component, :rendered_list_slots

    # ============================================
    # IR Resolution: Figma JSON -> IR hashes
    # ============================================

    # Top-level: resolve an entire component_set into IR.component or IR.multi_variant
    def resolve_component_set(component_set)
      default_variant = component_set.default_variant
      return nil unless default_variant&.figma_json.present?

      component_name = to_component_name(component_set.name)

      if component_set.is_image
        return Figma::IR.component(name: component_set.name, react_name: component_name,
                                    props: {}, tree: nil, is_image: true)
      end

      prop_definitions = component_set.prop_definitions || {}
      variant_prop_names = prop_definitions.select { |_, d| d["type"] == "VARIANT" }.keys
      all_variants = component_set.variants
        .select { |v| v.figma_json.present? }
        .sort_by { |v| [v.is_default ? 0 : 1, v.id] }

      # SVG icon component sets: use single_variant path so is_svg kicks in.
      # These are pure vector components where variant differences are just fill styles.
      default_node = default_variant.figma_json
      is_svg_component = vector_frame?(default_node) &&
        (@inline_svgs_by_node_id[default_node["id"]] || @inline_svgs_by_node_id[component_set.node_id])

      if variant_prop_names.any? && all_variants.size > 1 && !is_svg_component
        resolve_multi_variant(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
      else
        resolve_single_variant(component_name, default_variant, prop_definitions, component_set)
      end
    end

    # Top-level: resolve a standalone component into IR.component
    def resolve_component(component)
      figma = component.figma_json
      return nil unless figma.present?

      component_name = to_component_name(component.name)

      if component.is_image
        return Figma::IR.component(name: component.name, react_name: component_name,
                                    props: {}, tree: nil, is_image: true)
      end

      node = if figma["type"] == "COMPONENT_SET"
        default_variant_id = figma["defaultVariantId"]
        default_variant = (figma["children"] || []).find { |c| c["id"] == default_variant_id }
        default_variant || figma["children"]&.first || figma
      else
        figma
      end

      prop_definitions = component.prop_definitions || {}
      is_list = component.name.include?("#list") || component.description.to_s.include?("#list")

      setup_for_resolution(component_name, prop_definitions, node, is_list_component: is_list)

      instances, detached_nodes = collect_instances(node)
      imports_str = generate_imports(instances, detached_nodes)

      tree = resolve_node(node, is_root: true)
      promote_shadow_to_filled_child(tree)

      # Add imports for components referenced in INSTANCE_SWAP overrides
      all_imports = parse_imports(imports_str)
      @extra_instance_imports.each do |name|
        imp = "import { #{name} } from './#{name}';"
        all_imports << imp unless all_imports.include?(imp)
      end

      all_props = (@current_props || {}).dup

      # Pure vector-frame icons: the root IS the SVG, promote to is_svg component
      svg_content = if vector_frame?(node)
        @inline_svgs_by_node_id[node["id"]] || @inline_svgs_by_node_id[component.node_id]
      end

      Figma::IR.component(name: component.name, react_name: component_name,
                           props: all_props, tree: tree, imports: all_imports,
                           has_slot: @has_slot_during_resolve,
                           is_svg: !!svg_content, svg_content: svg_content)
    end

    def resolve_node(node, prop_definitions: nil, current_props: nil, slot_map: nil, is_root: false)
      return nil unless node.is_a?(Hash)

      pd = prop_definitions || @prop_definitions || {}
      cp = current_props || @current_props || {}
      sm = slot_map || @slot_map || {}

      # Handle detached instances first
      if node["_detached"] && node["_was_instance"]
        return resolve_detached_instance(node, pd, cp, sm)
      end

      # Visibility check
      prop_refs = node["componentPropertyReferences"] || {}
      visibility_ref = prop_refs["visible"]

      if visibility_ref
        prop = find_prop_for_reference(visibility_ref, cp)
        if prop
          if prop[:type] != "BOOLEAN"
            return nil if node["visible"] == false
          end
        else
          return nil if node["visible"] == false
        end
      else
        return nil if node["visible"] == false
      end

      # Determine visibility_prop for boolean-controlled nodes
      visibility_prop = nil
      if visibility_ref
        prop = find_prop_for_reference(visibility_ref, cp)
        if prop && prop[:type] == "BOOLEAN"
          visibility_prop = prop[:name]
        end
      end

      type = node["type"]

      ir = case type
      when "COMPONENT", "COMPONENT_SET", "FRAME", "GROUP"
        resolve_frame(node, pd, cp, sm, visibility_prop, is_root)
      when "TEXT"
        resolve_text(node, pd, cp, visibility_prop)
      when *VECTOR_TYPES
        resolve_shape(node, visibility_prop)
      when "INSTANCE"
        resolve_instance_ir(node, pd, cp, sm, visibility_prop)
      when "SLOT"
        resolve_slot_node(node, pd, cp, sm, visibility_prop)
      else
        resolve_frame(node, pd, cp, sm, visibility_prop, is_root)
      end

      ir
    end

    private

    # When a root frame has box-shadow but no background/border-radius,
    # the shadow renders as a rectangle in CSS. Move it to the first child
    # that has a background so the shadow follows the visual shape.
    def promote_shadow_to_filled_child(tree)
      return unless tree.is_a?(Hash) && tree[:kind] == :frame
      styles = tree[:styles] || {}
      return unless styles["box-shadow"] && !styles["background"]

      children = tree[:children] || []
      filled_child = children.find { |c| c.is_a?(Hash) && c[:styles]&.key?("background") }
      return unless filled_child

      existing = filled_child[:styles]["box-shadow"]
      new_shadow = styles.delete("box-shadow")
      filled_child[:styles]["box-shadow"] = existing ? "#{new_shadow}, #{existing}" : new_shadow

      # Compensate for pipeline screenshot padding mismatch.
      # The pipeline adds uniform shadow_pad = radius + spread + max(|ox|,|oy|) on all sides,
      # but Figma's render bounds use direction-specific extents. Without compensation,
      # vivid-colored components appear misaligned vs Figma (shifted right/down). Adding
      # negative margins to the root shrinks the effective canvas to match render bounds.
      if new_shadow =~ /(-?\d+(?:\.\d+)?)px\s+(-?\d+(?:\.\d+)?)px\s+(\d+(?:\.\d+)?)px\s+(\d+(?:\.\d+)?)px/
        ox = $1.to_f.abs
        oy = $2.to_f
        radius = $3.to_f
        spread = $4.to_f

        uniform_pad = radius + spread + [ox, oy.abs].max
        actual_top    = [radius + spread - oy,    0].max
        actual_bottom = [radius + spread + oy,    0].max
        actual_left   = [radius + spread - ox,    0].max
        actual_right  = [radius + spread + ox,    0].max

        mt = -(uniform_pad - actual_top).round
        mr = -(uniform_pad - actual_right).round
        mb = -(uniform_pad - actual_bottom).round
        ml = -(uniform_pad - actual_left).round

        if [mt, mr, mb, ml].any? { |m| m != 0 }
          styles["margin"] = "#{mt}px #{mr}px #{mb}px #{ml}px"
        end
      end
    end

    def resolve_frame(node, pd, cp, sm, visibility_prop, is_root = false)
      styles = extract_frame_styles(node, is_root)

      # When a node is conditionally rendered via a boolean prop (e.g. {checked && <div>}),
      # the prop-based conditional already handles visibility. Remove display:none so the
      # element is actually visible when the controlling prop is true.
      styles.delete("display") if visibility_prop && styles["display"] == "none"

      node_id = node["id"]
      # Don't inline root frames as PNG/SVG — they must render as component containers
      if !is_root && @inline_pngs_by_node_id[node_id]
        return Figma::IR.png_inline(node_id: node_id, name: node["name"] || "element",
                                     styles: styles, png_data: @inline_pngs_by_node_id[node_id],
                                     visibility_prop: visibility_prop)
      end
      if !is_root && vector_frame?(node) && @inline_svgs_by_node_id[node_id]
        has_resolvable_instance = (node["children"] || []).any? { |child|
          child["type"] == "INSTANCE" && child["componentId"] && (
            @components_by_node_id[child["componentId"]] ||
            @component_sets_by_node_id[child["componentId"]] ||
            @variants_by_node_id[child["componentId"]] ||
            (@component_key_by_node_id[child["componentId"]] && @variants_by_component_key[@component_key_by_node_id[child["componentId"]]])
          )
        }
        unless has_resolvable_instance
          # The exported SVG already visually encodes the frame's padding (content is
          # positioned within the full frame bounding box). Applying CSS padding on top
          # would double-pad the icon, shifting it visually. Strip padding from styles.
          svg_styles = styles.reject { |k, _| k =~ /^padding/ }
          return Figma::IR.svg_inline(node_id: node_id, name: node["name"] || "element",
                                       styles: svg_styles, svg_content: @inline_svgs_by_node_id[node_id],
                                       visibility_prop: visibility_prop)
        end
      end

      raw_children = node["children"] || []
      uses_absolute = !node["layoutMode"] && raw_children.any?

      child_positions = {}
      pending_mask_gradient = nil
      children = raw_children.each_with_index.filter_map do |child, idx|
        ir_child = resolve_node(child, prop_definitions: pd, current_props: cp, slot_map: sm)
        if ir_child
          # Handle absolute positioning: either parent has no layout (all children absolute)
          # or child explicitly opts out of flex with layoutPositioning: ABSOLUTE
          is_abs = uses_absolute || child["layoutPositioning"] == "ABSOLUTE"
          if is_abs
            pos_styles = extract_absolute_position(child, node)
            pos_styles["position"] = "absolute"
            # For LEFT_RIGHT + TOP_BOTTOM constraints, stretch to parent
            constraints = child["constraints"] || {}
            if constraints["horizontal"] == "LEFT_RIGHT" && constraints["vertical"] == "TOP_BOTTOM"
              pos_styles = { "position" => "absolute", "top" => "0", "left" => "0", "right" => "0", "bottom" => "0" }
            end

            if child["isMask"] == true && child["maskType"] == "ALPHA"
              # Figma alpha mask: the gradient's alpha channel controls sibling visibility.
              # Hide this rect and apply its gradient as mask-image on the next sibling.
              mask_fills = (child["fills"] || []).select { |f| f["visible"] != false }
              if mask_fills.any? && mask_fills.first["type"] == "GRADIENT_LINEAR"
                pending_mask_gradient = alpha_mask_gradient(mask_fills.first)
              end
              pos_styles["display"] = "none"
            elsif pending_mask_gradient
              # Apply the alpha mask from the previous sibling to this element's wrapper
              pos_styles["mask-image"] = pending_mask_gradient
              pos_styles["-webkit-mask-image"] = pending_mask_gradient
              pending_mask_gradient = nil
            end

            child_positions[ir_child[:node_id]] = { index: idx, styles: pos_styles }
          else
            pending_mask_gradient = nil
          end
        end
        ir_child
      end

      Figma::IR.frame(node_id: node_id, name: node["name"] || "element",
                       styles: styles, children: children,
                       visibility_prop: visibility_prop,
                       uses_absolute: uses_absolute, child_positions: child_positions)
    end

    def resolve_text(node, pd, cp, visibility_prop)
      styles = extract_text_styles(node)
      text = node["characters"] || ""

      prop_refs = node["componentPropertyReferences"] || {}
      characters_ref = prop_refs["characters"]

      text_prop = nil
      if characters_ref
        prop = find_prop_for_reference(characters_ref, cp)
        if prop && prop[:type] == "TEXT"
          text_prop = prop[:name]
        end
      end

      Figma::IR.text(node_id: node["id"], name: node["name"] || "element",
                      styles: styles, text_content: text, text_prop: text_prop,
                      visibility_prop: visibility_prop)
    end

    def resolve_shape(node, visibility_prop)
      styles = extract_shape_styles(node)

      node_id = node["id"]
      if @inline_pngs_by_node_id[node_id]
        return Figma::IR.png_inline(node_id: node_id, name: node["name"] || "element",
                                     styles: styles, png_data: @inline_pngs_by_node_id[node_id],
                                     visibility_prop: visibility_prop)
      end
      if @inline_svgs_by_node_id[node_id]
        return Figma::IR.svg_inline(node_id: node_id, name: node["name"] || "element",
                                     styles: styles, svg_content: @inline_svgs_by_node_id[node_id],
                                     visibility_prop: visibility_prop)
      end

      Figma::IR.shape(node_id: node["id"], name: node["name"] || "element",
                       styles: styles, visibility_prop: visibility_prop)
    end

    def resolve_instance_ir(node, pd, cp, sm, visibility_prop)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")

      # Check for list component dedup (INSTANCE_SWAP in a #list component)
      if @is_list_component && ref && instance_swap_ref?(ref, pd)
        @rendered_list_slots ||= []
        if @rendered_list_slots.include?(ref)
          return nil  # already rendered this slot once
        else
          @rendered_list_slots << ref
          @has_slot_during_resolve = true
          slot_name = sm[node["id"]] || "children"
          return Figma::IR.slot(node_id: node["id"], name: node["name"] || "element",
                                 prop_name: slot_name, visibility_prop: visibility_prop)
        end
      end

      # Check for image swap first
      if ref && image_swap_instance?(node, pd)
        prop_name = to_prop_name(strip_ref_suffix(ref))
        styles = extract_frame_styles(node, false) rescue {}
        return Figma::IR.image_swap(node_id: node["id"], name: node["name"] || "element",
                                     prop_name: prop_name, styles: styles,
                                     visibility_prop: visibility_prop)
      end

      # Check for slot (INSTANCE_SWAP with preferredValues)
      if ref && slot_instance?(node, pd)
        @has_slot_during_resolve = true
        slot_name = sm[node["id"]] || to_prop_name(strip_ref_suffix(ref))
        return Figma::IR.slot(node_id: node["id"], name: node["name"] || "element",
                               prop_name: slot_name, visibility_prop: visibility_prop)
      end

      # Check for icon swap (INSTANCE_SWAP without preferredValues)
      if (swap_prop = instance_swap_prop_name(node, pd))
        # If we have SVG content for this instance, inline it instead of
        # creating a component prop that requires the consumer to pass a value
        svg_content = find_svg_for_instance_swap(node)
        if svg_content
          styles = extract_frame_styles(node, false)
          # Apply icon color/opacity from instance children fills
          overrides = extract_instance_style_overrides(node)
          styles.merge!(overrides.slice("color", "opacity"))
          return Figma::IR.svg_inline(node_id: node["id"], name: node["name"] || "element",
                                       styles: styles, svg_content: svg_content,
                                       visibility_prop: visibility_prop)
        end

        overrides = extract_instance_style_overrides(node)
        placeholder_styles, placeholder_text = extract_icon_swap_placeholder_styles(node)
        return Figma::IR.icon_swap(node_id: node["id"], name: node["name"] || "element",
                                    prop_name: swap_prop, style_overrides: overrides,
                                    placeholder_styles: placeholder_styles,
                                    placeholder_text: placeholder_text,
                                    visibility_prop: visibility_prop)
      end

      # Regular instance — resolve to component_ref or unresolved
      component_id = node["componentId"]
      return Figma::IR.unresolved(node_id: node["id"], name: node["name"] || "element",
                                   styles: {}, instance_name: node["name"] || "unknown") unless component_id

      # Try to resolve via lookups — need both name and component_set for override extraction
      comp_name, component_set = resolve_instance_name_and_set(node)
      if comp_name
        prop_overrides, extra_imports = extract_instance_override_props_for_ir(node, component_set)
        # Track extra imports from INSTANCE_SWAP overrides (e.g. StartIconComponent=Plus)
        extra_imports.each { |name| @extra_instance_imports << name } if extra_imports.any?
        style_overrides = extract_instance_style_overrides(node)
        return Figma::IR.component_ref(node_id: node["id"], name: node["name"] || "element",
                                        component_name: comp_name, prop_overrides: prop_overrides,
                                        style_overrides: style_overrides,
                                        visibility_prop: visibility_prop)
      end

      # Unresolved
      styles = extract_frame_styles(node, false)
      bbox = node["absoluteBoundingBox"] || {}
      w = bbox["width"]&.round
      h = bbox["height"]&.round
      styles["background"] = "#FF69B4"
      styles["width"] = "#{w}px" if w
      styles["height"] = "#{h}px" if h

      track_unresolved_instance(component_id, node["name"] || "unknown")

      Figma::IR.unresolved(node_id: node["id"], name: node["name"] || "element",
                            styles: styles, instance_name: node["name"] || "unknown")
    end

    def resolve_slot_node(node, pd, cp, sm, visibility_prop)
      @has_slot_during_resolve = true
      styles = extract_frame_styles(node, false)
      styles["min-width"] = "0" if styles["flex-grow"] || styles["align-self"]
      styles["overflow"] = "hidden" if styles["flex-grow"]
      slot_name = sm[node["id"]] || "children"
      Figma::IR.figma_slot(node_id: node["id"], name: node["name"] || "element",
                            prop_name: slot_name, styles: styles,
                            visibility_prop: visibility_prop)
    end

    def resolve_detached_instance(node, pd, cp, sm)
      prop_refs = node["componentPropertyReferences"] || {}
      main_component_ref = prop_refs["mainComponent"]

      component_set = find_component_set_for_detached(node)

      if component_set
        component_name = to_component_name(component_set.name)
        instance_key = node["_instance_key"]

        props_parts = []
        if instance_key
          prop_definitions = component_set.prop_definitions || {}
          prop_definitions.each do |key, definition|
            if definition["type"] == "TEXT"
              clean_name = key.gsub(/#[\d:]+$/, "").strip
              original_prop_name = to_prop_name(clean_name)
              namespaced_prop_name = "#{instance_key}#{original_prop_name.sub(/^(\w)/) { $1.upcase }}"
              if @nested_instance_props && @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_prop_name}={#{namespaced_prop_name}}"
              end
            elsif definition["type"] == "INSTANCE_SWAP"
              clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s\u21B3]+/, "")
              original_prop_name = to_prop_name(clean_name)
              original_component_name = original_prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
              namespaced_prop_name = "#{instance_key}#{original_component_name}"
              if @nested_instance_props && @nested_instance_props[namespaced_prop_name]
                props_parts << "#{original_component_name}={#{namespaced_prop_name}}"
              end
            end
          end
        else
          overridden_props = extract_overridden_props(node, component_set)
          overridden_props.each { |k, v| props_parts << "#{k}={#{v}}" }
        end

        swap_component_name = nil
        if main_component_ref
          prop = find_prop_for_reference(main_component_ref, cp)
          if prop && prop[:type] == "INSTANCE_SWAP"
            swap_component_name = prop[:name].sub(/^(\w)/) { $1.upcase } + "Component"
          end
        end

        return Figma::IR.detached_ref(node_id: node["id"], name: node["name"] || "element",
                                       component_name: component_name, props_parts: props_parts,
                                       swap_component_name: swap_component_name)
      end

      # Not a known component — try SVG fallback
      svg_content = find_svg_for_detached(node)
      if svg_content
        styles = extract_frame_styles(node, false)
        styles = styles.merge(
          "display" => "inline-flex",
          "align-items" => "center",
          "justify-content" => "center"
        )
        return Figma::IR.detached_svg(node_id: node["id"], name: node["name"] || "element",
                                       styles: styles, svg_content: svg_content)
      end

      # Fallback: empty div
      styles = extract_frame_styles(node, false)
      Figma::IR.frame(node_id: node["id"], name: node["name"] || "element",
                       styles: styles, children: [])
    end

    def resolve_single_variant(component_name, default_variant, prop_definitions, component_set)
      node = default_variant.figma_json
      is_list = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")

      setup_for_resolution(component_name, prop_definitions, node, is_list_component: is_list)

      instances, detached_nodes = collect_instances(node)
      imports_str = generate_imports(instances, detached_nodes)

      tree = resolve_node(node, is_root: true)
      promote_shadow_to_filled_child(tree)

      all_imports = parse_imports(imports_str)
      @extra_instance_imports.each do |name|
        imp = "import { #{name} } from './#{name}';"
        all_imports << imp unless all_imports.include?(imp)
      end

      all_props = (@current_props || {}).merge(@nested_instance_props || {})

      # Pure vector-frame icons: the root IS the SVG, promote to is_svg component.
      # SVG assets may be keyed by the variant node or the component_set node.
      svg_content = if vector_frame?(node)
        @inline_svgs_by_node_id[node["id"]] || @inline_svgs_by_node_id[component_set.node_id]
      end

      Figma::IR.component(name: component_set.name, react_name: component_name,
                           props: all_props, tree: tree, imports: all_imports,
                           has_slot: @has_slot_during_resolve, nested_props: @nested_instance_props || {},
                           is_svg: !!svg_content, svg_content: svg_content)
    end

    def resolve_multi_variant(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
      variant_entries = all_variants.each_with_index.map do |variant, idx|
        node = variant.figma_json
        is_list = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")

        setup_for_resolution(component_name, prop_definitions, node, is_list_component: is_list)

        instances, detached_nodes = collect_instances(node)
        imports_str = generate_imports(instances, detached_nodes)

        tree = resolve_node(node, is_root: true)
        promote_shadow_to_filled_child(tree)

        all_imports = parse_imports(imports_str)
        @extra_instance_imports.each do |name|
          imp = "import { #{name} } from './#{name}';"
          all_imports << imp unless all_imports.include?(imp)
        end

        non_variant_props = (@current_props || {}).merge(@nested_instance_props || {}).reject { |_, p| p[:type] == "VARIANT" }

        Figma::IR.variant_entry(
          index: idx,
          variant_properties: variant.variant_properties,
          props: non_variant_props,
          tree: tree,
          imports: all_imports,
          has_slot: @has_slot_during_resolve,
          nested_props: @nested_instance_props || {},
          variant_record: variant
        )
      end

      Figma::IR.multi_variant(
        name: component_set.name,
        react_name: component_name,
        variant_prop_names: variant_prop_names,
        prop_definitions: prop_definitions,
        variants: variant_entries
      )
    end

    # Set up mutable state for a resolution pass (replaces ReactFactory#create_emitter setup)
    def setup_for_resolution(component_name, prop_definitions, node, is_list_component: false)
      @nested_instance_counters = {}
      @nested_instance_props = {}
      @is_list_component = is_list_component
      @prop_definitions = prop_definitions
      @rendered_list_slots = []
      @has_slot_during_resolve = false
      @extra_instance_imports = Set.new

      @current_props = extract_props(prop_definitions, node)
      @slot_map = build_slot_map(node, prop_definitions)
      collect_nested_instance_props(node)
    end

    def parse_imports(imports_str)
      return [] if imports_str.blank?
      imports_str.split("\n").reject(&:blank?)
    end

    public

    def extract_props(prop_definitions_hash, variant_tree = nil)
      props = {}
      return props unless prop_definitions_hash.is_a?(Hash)

      prop_names_by_type = {}
      prop_definitions_hash.each do |key, definition|
        prop_type = definition["type"]
        clean_name = key.gsub(/#[\d:]+$/, "").strip
        clean_name = clean_name.gsub(/^[\s\u21B3]+/, "").strip
        prop_name = to_prop_name(clean_name)
        prop_names_by_type[prop_name] ||= []
        prop_names_by_type[prop_name] << prop_type
      end

      prop_definitions_hash.each do |key, definition|
        prop_type = definition["type"]
        default_value = definition["defaultValue"]

        clean_name = key.gsub(/#[\d:]+$/, "").strip
        is_nested = key.start_with?("\u21B3") || key.match?(/^[\s\u21B3]+/)
        clean_name = clean_name.gsub(/^[\s\u21B3]+/, "").strip

        prop_name = to_prop_name(clean_name)

        if prop_names_by_type[prop_name]&.length.to_i > 1
          if prop_type == "TEXT"
            prop_name = "#{prop_name}Content"
          end
        end

        if prop_type == "INSTANCE_SWAP"
          preferred = definition["preferredValues"] || []
          if preferred.any? && preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
            prop_type = "TEXT"
            default_value = ""
          elsif default_value.present? && variant_tree
            instance_node = find_node_by_component_id(variant_tree, default_value)
            component_set = find_component_set_for_detached(instance_node) if instance_node
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

    def find_prop_for_reference(reference_key, current_props_hash = nil)
      cp = current_props_hash || @current_props || {}
      cp[reference_key] || cp[strip_ref_suffix(reference_key)]
    end

    def find_prop_definition(reference_key, prop_defs = nil)
      pd = prop_defs || @prop_definitions || {}
      pd[reference_key] || pd[strip_ref_suffix(reference_key)]
    end

    def strip_ref_suffix(key)
      key.to_s.gsub(/#[\d:]+$/, "").strip
    end

    def slot_instance?(node, prop_defs = nil)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return false unless ref
      return false if image_swap_instance?(node, prop_defs)

      defn = find_prop_definition(ref, prop_defs)
      return false unless defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?

      # Only treat as slot if preferred values include non-component-set entries
      # (i.e. actual content slots). If all preferred values are component sets
      # (icon libraries), treat as icon swap instead.
      preferred = defn["preferredValues"] || []
      preferred.any? { |pv| pv["type"] != "COMPONENT_SET" }
    end

    def instance_swap_prop_name(node, prop_defs = nil)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return nil unless ref

      defn = find_prop_definition(ref, prop_defs)
      return nil unless defn&.dig("type") == "INSTANCE_SWAP"

      # Allow icon swaps: no preferred values, or all preferred are component sets (icon libraries)
      preferred = defn["preferredValues"] || []
      return nil if preferred.any? && preferred.any? { |pv| pv["type"] != "COMPONENT_SET" }

      clean_key = ref.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s\u21B3]+/, "").strip
      to_prop_name(clean_key).sub(/^(\w)/) { $1.upcase } + "Component"
    end

    def extract_instance_style_overrides(node)
      style = {}

      (node["children"] || []).each do |child|
        fills = child["fills"]
        next unless fills.is_a?(Array) && fills.any?

        fill = fills.find { |f| f["type"] == "SOLID" && f["visible"] != false && f["color"] }
        next unless fill

        c = fill["color"]
        r = (c["r"] * 255).round
        g = (c["g"] * 255).round
        b = (c["b"] * 255).round
        a = (c["a"] || 1.0) * (fill["opacity"] || 1.0)

        # Skip fully opaque black (default color, no override needed)
        next if r == 0 && g == 0 && b == 0 && a >= 0.99

        # Very transparent black overlays are visual fade effects, not text colors.
        # Use opacity instead so the entire sub-component is faded.
        if r == 0 && g == 0 && b == 0 && a < 0.3
          style["opacity"] = (1.0 - a).round(2).to_s
        elsif a < 0.99
          style["color"] = "rgba(#{r}, #{g}, #{b}, #{a.round(2)})"
        else
          style["color"] = "#%02x%02x%02x" % [r, g, b]
        end
        break
      end

      # Check the first FRAME child of the instance for distinctly colored strokes.
      # In Figma, state overrides (e.g. error-state red border) are sometimes applied
      # to an inner frame inside an INSTANCE rather than the instance's container frame.
      # We bubble those up as a boxShadow style override so the emitter can render them
      # as an inset border on the component wrapper span.
      # Dark/black strokes are the library component's own default border — skip those
      # to avoid adding a double border on top of the component's internal styling.
      first_frame = (node["children"] || []).find { |c| c["type"] == "FRAME" }
      if first_frame && !style.key?("boxShadow")
        frame_strokes = first_frame["strokes"] || []
        visible_stroke = frame_strokes.find { |s| s["visible"] != false && s["color"] }
        if visible_stroke
          sc = visible_stroke["color"]
          sr, sg, sb = sc["r"].to_f, sc["g"].to_f, sc["b"].to_f
          # Only bubble up non-dark colored strokes (e.g. error red, not default gray/black)
          unless sr < 0.3 && sg < 0.3 && sb < 0.3
            weight = first_frame["strokeWeight"] || 1
            css_color = figma_color_to_css(sc, visible_stroke["opacity"])
            style["boxShadow"] = "inset 0 0 0 #{weight}px #{css_color}"
          end
        end
      end

      bbox = node["absoluteBoundingBox"]
      if bbox
        w = bbox["width"]&.round
        h = bbox["height"]&.round
        style["width"] = "#{w}px" if w && w > 0
        style["height"] = "#{h}px" if h && h > 0
      end

      style
    end

    # Extract visual appearance styles from an icon-swap node itself (not its children)
    # so the emitter can render a placeholder when no component prop is provided.
    # Returns [styles_hash, text_label] where text_label is any centered text found inside.
    def extract_icon_swap_placeholder_styles(node)
      styles = {}

      # Background fill from node's own fills
      fills = node["fills"]
      if fills.is_a?(Array)
        fill = fills.find { |f| f["type"] == "SOLID" && f["visible"] != false && f["color"] }
        if fill
          styles["background"] = figma_color_to_css(fill["color"], fill["opacity"])
        end
      end

      # Border from node's own strokes
      strokes = node["strokes"]
      if strokes.is_a?(Array) && strokes.any?
        stroke = strokes.find { |s| s["visible"] != false && s["color"] }
        if stroke
          weight = (node["strokeWeight"] || 1).round
          color = figma_color_to_css(stroke["color"], stroke["opacity"])
          dashes = node["strokeDashes"]
          style_word = (dashes.is_a?(Array) && dashes.any?) ? "dashed" : "solid"
          styles["border"] = "#{weight}px #{style_word} #{color}"
        end
      end

      # Border radius
      r = node["cornerRadius"]
      styles["borderRadius"] = "#{r.round}px" if r && r > 0

      # Dimensions from absoluteBoundingBox
      bbox = node["absoluteBoundingBox"]
      if bbox
        w = bbox["width"]&.round
        h = bbox["height"]&.round
        styles["width"] = "#{w}px" if w && w > 0
        styles["height"] = "#{h}px" if h && h > 0
      end

      # Extract centered label text from children (e.g. "Swap-area" placeholder text)
      label_text = nil
      (node["children"] || []).each do |child|
        next unless child["type"] == "TEXT"
        chars = child["characters"]
        label_text = chars if chars && !chars.strip.empty?
        break
      end

      # Add flex centering to the placeholder if we have a text label to display
      if label_text
        styles["display"] = "flex"
        styles["alignItems"] = "center"
        styles["justifyContent"] = "center"
      end

      [styles, label_text]
    end

    def image_swap_instance?(node, prop_defs = nil)
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      return false unless ref

      defn = find_prop_definition(ref, prop_defs)
      return false unless defn&.dig("type") == "INSTANCE_SWAP"

      preferred = defn["preferredValues"] || []
      preferred.any? && preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
    end

    def instance_swap_ref?(ref, prop_defs = nil)
      find_prop_definition(ref, prop_defs)&.dig("type") == "INSTANCE_SWAP"
    end

    def build_slot_map(node, prop_definitions_hash)
      entries = []

      walk = ->(n) do
        return unless n.is_a?(Hash)
        if n["type"] == "SLOT"
          ref = n.dig("componentPropertyReferences", "slotContentId")
          entries << { ref: ref, node_id: n["id"] } if ref
          next
        elsif n["type"] == "INSTANCE"
          ref = n.dig("componentPropertyReferences", "mainComponent")
          if ref
            defn = prop_definitions_hash[ref] || prop_definitions_hash[strip_ref_suffix(ref)]
            if defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?
              preferred = defn["preferredValues"] || []
              unless preferred.all? { |pv| image_component_keys.include?(pv["key"]) }
                entries << { ref: ref, node_id: n["id"] }
              end
            end
          end
          next
        end
        (n["children"] || []).each { |c| walk.call(c) }
      end
      walk.call(node)

      unique_refs = entries.map { |e| strip_ref_suffix(e[:ref]) }.uniq

      map = {}
      entries.each do |e|
        name = to_prop_name(strip_ref_suffix(e[:ref]))
        map[e[:node_id]] = name
      end
      map
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

          prop_defs = component_set.prop_definitions || {}

          prop_defs.each do |key, definition|
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
              clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s\u21B3]+/, "")
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

    def find_component_set_for_detached(node)
      original_child_ids = extract_original_child_ids(node)

      original_child_ids.each do |node_id|
        component_set = @node_id_to_component_set[node_id]
        return component_set if component_set
      end

      nil
    end

    def find_component_set_by_any_node_id(node_id)
      return nil unless node_id.present?

      cs = @component_sets_by_node_id[node_id]
      return cs if cs

      variant = @variants_by_node_id[node_id]
      return variant.component_set if variant

      @node_id_to_component_set[node_id]
    end

    def find_node_by_component_id(node, component_id)
      return nil unless node.is_a?(Hash)
      return node if node["componentId"] == component_id
      (node["children"] || []).each do |child|
        result = find_node_by_component_id(child, component_id)
        return result if result
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

    # Find SVG content for a large INSTANCE_SWAP node (e.g. illustration)
    # by looking up FigmaAsset by node_id
    def find_svg_for_instance_swap(node)
      node_id = node["id"]
      return nil unless node_id

      asset = FigmaAsset.find_by(node_id: node_id, asset_type: "svg")
      return asset.content if asset&.content.present?

      # Try by componentId
      component_id = node["componentId"]
      if component_id
        asset = FigmaAsset.find_by(node_id: component_id, asset_type: "svg")
        return asset.content if asset&.content.present?
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

    def lookup_component_set_name_for_variant(variant_node_id)
      @figma_components_cache ||= {}

      @figma_file_keys.each do |file_key|
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

    def extract_overridden_props(node, component_set)
      props = {}
      prop_defs = component_set.prop_definitions || {}

      prop_defs.each do |key, definition|
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
          clean_name = key.gsub(/#[\d:]+$/, "").strip.gsub(/^[\s\u21B3]+/, "")
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

    def resolve_instance_component_name(node)
      component_id = node["componentId"]
      return nil unless component_id

      ref = @components_by_node_id[component_id]
      return to_component_name(ref.name) if ref

      ref_set = @component_sets_by_node_id[component_id]
      return to_component_name(ref_set.name) if ref_set

      variant = @variants_by_node_id[component_id]
      return to_component_name(variant.component_set.name) if variant

      comp_key = @component_key_by_node_id[component_id]
      if comp_key
        variant = @variants_by_component_key[comp_key]
        return to_component_name(variant.component_set.name) if variant
      end

      nil
    end

    # Like resolve_instance_component_name but also returns the component_set
    # for extracting override props. Returns [name, component_set] or [nil, nil].
    def resolve_instance_name_and_set(node)
      component_id = node["componentId"]
      return [nil, nil] unless component_id

      ref = @components_by_node_id[component_id]
      return [to_component_name(ref.name), ref] if ref  # standalone component — pass it for prop extraction

      ref_set = @component_sets_by_node_id[component_id]
      return [to_component_name(ref_set.name), ref_set] if ref_set

      variant = @variants_by_node_id[component_id]
      return [to_component_name(variant.component_set.name), variant.component_set] if variant

      comp_key = @component_key_by_node_id[component_id]
      if comp_key
        variant = @variants_by_component_key[comp_key]
        return [to_component_name(variant.component_set.name), variant.component_set] if variant
      end

      [nil, nil]
    end

    # Extract componentProperties overrides from an INSTANCE node as a hash
    # suitable for IR prop_overrides. Only includes props that differ from defaults.
    # Returns [overrides_hash, extra_import_names_array].
    def extract_instance_override_props_for_ir(node, component_set)
      overrides = {}
      extra_imports = []
      component_properties = node["componentProperties"]
      return [overrides, extra_imports] unless component_properties.is_a?(Hash) && component_properties.any?
      return [overrides, extra_imports] unless component_set

      prop_definitions = component_set.prop_definitions || {}

      # Build a map from INSTANCE_SWAP prop key to child node
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

        # For nested/forwarded props (↳ prefix), name won't match target's prop_definitions.
        # Fall back to type-based matching: if the target has exactly one TEXT prop, use it.
        if matching_def_key.nil? && clean_key.include?("\u21B3") && prop_type == "TEXT"
          text_def_keys = prop_definitions.select { |_, d| d["type"] == "TEXT" }.keys
          matching_def_key = text_def_keys.first if text_def_keys.size == 1
        end

        definition = matching_def_key ? prop_definitions[matching_def_key] : nil

        # Skip if value matches default
        next if definition && definition["defaultValue"].to_s == value.to_s

        # Use the matched prop definition key for the prop name so it aligns with the
        # target component's compiled prop interface (avoids name mismatches for nested props).
        effective_name_key = matching_def_key ? matching_def_key.gsub(/#[\d:]+$/, "").strip : clean_key.gsub(/^[\s\u21B3]+/, "").strip
        prop_name = to_prop_name(effective_name_key)

        case prop_type
        when "VARIANT"
          overrides[prop_name] = "\"#{value}\""
        when "TEXT"
          overrides[prop_name] = "\"#{value}\""
        when "BOOLEAN"
          overrides[prop_name] = "{#{value}}"
        when "INSTANCE_SWAP"
          preferred = definition&.dig("preferredValues") || []
          if preferred.empty? || preferred.all? { |pv| pv["type"] == "COMPONENT_SET" }
            # No preferredValues or icon library — resolve as component reference
            child_node = children_by_swap_ref[key]
            next unless child_node
            comp_name = resolve_instance_component_name(child_node)
            next unless comp_name
            component_prop_name = prop_name.sub(/^(\w)/) { $1.upcase } + "Component"
            overrides[component_prop_name] = comp_name
            extra_imports << comp_name
          end
          # INSTANCE_SWAP with mixed preferredValues (slot content) is complex —
          # rendered by the parent component's slot mechanism.
        end
      end

      [overrides, extra_imports]
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

    private

    def log(message)
      puts "[Figma::Resolver] #{message}"
    end

  end
end
