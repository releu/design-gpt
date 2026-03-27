# Figma node -> JSX + CSS code generation.
# Takes Figma JSON nodes and produces React component code strings.
# Uses Resolver for component lookups, prop resolution, etc.
module Figma
  class Emitter
    include Figma::StyleExtractor

    attr_reader :css_rules
    attr_accessor :has_slot

    def initialize(component_name)
      @component_name = component_name
      @class_index = 0
      @css_rules = {}
      @has_slot = false
    end

    # --- IR-based emission ---

    # Top-level: emit a full component code string from an IR.component
    def emit(ir)
      case ir[:kind]
      when :component then emit_component(ir)
      when :multi_variant then emit_multi_variant(ir)
      else raise "Unknown IR kind for emit: #{ir[:kind]}"
      end
    end

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
      when :detached_ref then emit_detached_ref(ir_node)
      when :detached_svg then emit_detached_svg(ir_node)
      when :figma_slot then emit_figma_slot(ir_node)
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

    # --- Full component emission from IR ---

    def emit_component(ir)
      @component_name = ir[:react_name]
      @class_index = 0
      @css_rules = {}
      @has_slot = ir[:has_slot]

      if ir[:is_image]
        return generate_image_component_code(ir[:react_name])
      end

      if ir[:is_svg]
        return generate_svg_component_code(ir[:react_name], ir[:svg_content])
      end

      jsx = emit_node(ir[:tree], 0, is_root: true)
      css = generate_css(@css_rules)

      imports = (ir[:imports] || []).join("\n")
      all_props = (ir[:props] || {}).merge(ir[:nested_props] || {})

      build_component_code(ir[:react_name], imports, css, jsx, all_props, has_slot: @has_slot)
    end

    def emit_multi_variant(ir)
      component_name = ir[:react_name]
      variant_prop_names = ir[:variant_prop_names]
      prop_definitions = ir[:prop_definitions]
      all_imports = []

      variant_entries = ir[:variants].map do |v_ir|
        @component_name = component_name
        @class_index = 0
        @css_rules = {}
        @has_slot = v_ir[:has_slot]

        scope_id = "#{component_name.downcase.gsub(/[^a-z0-9]/, "")}v#{v_ir[:index]}"

        jsx = emit_node(v_ir[:tree], 0, is_root: true)
        css = generate_css(@css_rules)

        scoped_css = css.gsub(/^\.([a-z0-9_-]+)/i) { ".#{scope_id}-#{$1}" }
        scoped_jsx = jsx.gsub(/className="([^"]+)"/) { "className=\"#{scope_id}-#{$1}\"" }

        variant_classes = variant_prop_names.filter_map do |prop_key|
          clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
          prop_css = clean_key.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_]/, "")
          val = v_ir[:variant_properties][clean_key.downcase]
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

        imports_str = (v_ir[:imports] || []).join("\n")
        all_imports << imports_str if imports_str.present?

        {
          index: v_ir[:index],
          func_name: "#{component_name}__v#{v_ir[:index]}",
          css: scoped_css,
          jsx: scoped_jsx,
          variant_properties: v_ir[:variant_properties],
          props: v_ir[:props],
          has_slot: v_ir[:has_slot],
          is_default: v_ir[:variant_record]&.is_default,
          variant_record: v_ir[:variant_record],
          imports: imports_str
        }
      end

      { variant_entries: variant_entries, all_imports: all_imports }
    end

    # --- Code generation helpers (used by emit_component / emit_multi_variant) ---

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

      clean_svg = clean_svg
        .gsub(/fill="(?:#000(?:000)?|black|rgb\(0,\s*0,\s*0\))"/i, 'fill="currentColor"')
        .gsub(/stroke="(?:#000(?:000)?|black|rgb\(0,\s*0,\s*0\))"/i, 'stroke="currentColor"')
      # Add fill="currentColor" to <path> elements that lack an explicit fill,
      # so CSS color inheritance works for icon coloring.
      clean_svg = clean_svg.gsub(/<path(?![^>]*\bfill=)([^>]*?)(\s*\/?>)/) do
        "<path fill=\"currentColor\"#{$1}#{$2}"
      end

      w = clean_svg.match(/width="(\d+(?:\.\d+)?)"/)&.captures&.first
      h = clean_svg.match(/height="(\d+(?:\.\d+)?)"/)&.captures&.first
      default_style = if w && h
        "{ width: '#{w}px', height: '#{h}px', flexShrink: 0 }"
      else
        "{ flexShrink: 0 }"
      end

      # Make SVG fill its container so parent size overrides work
      scalable_svg = clean_svg
        .gsub(/(<svg[^>]*)\bwidth="[\d.]+"/, '\\1width="100%"')
        .gsub(/(<svg[^>]*)\bheight="[\d.]+"/, '\\1height="100%"')
        .sub(/<svg/, '<svg style="display:block"')

      <<~CODE
        import React from 'react';

        const svg = `#{scalable_svg.gsub('`', '\\`')}`;

        export function #{component_name}({ style: __passedStyle, ...props }) {
          return (
            <div data-component="#{component_name}" style={{...#{default_style}, ...__passedStyle}} dangerouslySetInnerHTML={{__html: svg}} {...props} />
          );
        }

        export default #{component_name};
      CODE
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

    def build_variant_component_code(component_name, all_imports, variant_entries, variant_prop_names, prop_definitions)
      imports_section = all_imports.flat_map { |i| i.split("\n") }.uniq.join("\n")
      imports_section = imports_section.present? ? "#{imports_section}\n" : ""

      combined_css = variant_entries.map { |e| e[:css] }.join("\n")

      variant_functions = variant_entries.map do |entry|
        props_destructuring = generate_props_destructuring(entry[:props])
        <<~FUNC.chomp
          function #{entry[:func_name]}(#{props_destructuring}) {
            return (#{entry[:jsx]});
          }
        FUNC
      end.join("\n\n")

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

    def generate_per_variant_code(entry)
      imports_section = entry[:imports].present? ? "#{entry[:imports]}\n" : ""
      <<~CODE
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

    private

    def to_prop_name(name)
      clean_name = name.to_s.gsub(/[^\w\s-]/i, "").strip
      return clean_name if clean_name.match?(/\A[a-z][a-zA-Z0-9]*\z/)

      words = clean_name.split(/[\s_-]+/).reject(&:empty?)
      return "prop" if words.empty?

      first = words.first.downcase.gsub(/[^a-z0-9]/i, "")
      rest = words[1..].map { |w| w.gsub(/[^a-z0-9]/i, "").capitalize }.join

      result = first + rest
      result = "prop#{result}" if result.match?(/^\d/)
      result.empty? ? "prop" : result
    end

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

    # --- IR node emission helpers ---

    def emit_frame(ir, depth, is_root: false)
      class_name = generate_class_name(ir[:name], is_root)
      styles = ir[:styles].dup
      neg_spacing = styles.delete("--negative-spacing")
      neg_direction = styles.delete("--negative-spacing-direction")
      @css_rules[class_name] = styles

      uses_absolute = ir[:uses_absolute]
      child_positions = ir[:child_positions] || {}

      child_idx = 0
      children_jsx = ir[:children].each_with_index.map do |child, idx|
        child_jsx = emit_node(child, depth + 1)
        if child_jsx.present?
          pos = child_positions[child[:node_id]]
          if pos
            wrapper_class = "#{class_name}-pos-#{pos[:index]}"
            @css_rules[wrapper_class] = pos[:styles]
            child_jsx = "<div className=\"#{wrapper_class}\">#{child_jsx}</div>"
          end
          # Apply negative spacing as margin on children after the first
          if neg_spacing && child_idx > 0
            overlap_class = "#{class_name}-overlap"
            @css_rules[overlap_class] ||= { neg_direction => neg_spacing }
            child_jsx = "<div className=\"#{overlap_class}\">#{child_jsx}</div>"
          end
          child_idx += 1
        end
        child_jsx
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
      props_string = if ir[:prop_overrides].any?
        " " + ir[:prop_overrides].map { |k, v|
          if v.start_with?('"') || v.start_with?("{")
            "#{k}=#{v}"
          else
            "#{k}={#{v}}"
          end
        }.join(" ")
      else
        ""
      end

      component_jsx = "<#{ir[:component_name]}#{props_string} />"

      # Wrap in styled span if style overrides exist (e.g. color/size for icon instances)
      if ir[:style_overrides]&.any?
        style_pairs = ir[:style_overrides].map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
        size_pairs = ir[:style_overrides].select { |k, _| %w[width height].include?(k) }
          .map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
        icon_style = size_pairs.empty? ? "" : " style={{#{size_pairs}}}"
        "<span style={{display: \"inline-flex\", #{style_pairs}}}>#{component_jsx.sub(' />', "#{icon_style} />")}</span>"
      else
        component_jsx
      end
    end

    def emit_icon_swap(ir)
      prop = ir[:prop_name]
      if ir[:style_overrides].any?
        style_pairs = ir[:style_overrides].map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
        # Extract size-related styles to pass to the icon component so SVG icons
        # can scale (they use width/height from passed style to override defaults).
        size_pairs = ir[:style_overrides].select { |k, _| %w[width height].include?(k) }
          .map { |k, v| "#{k}: \"#{v}\"" }.join(", ")
        icon_style = size_pairs.empty? ? "" : " style={{#{size_pairs}}}"
        # Wrap icon in a styled span so color/size overrides work regardless of
        # whether the icon is an SVG component (spreads props) or a regular
        # multi-variant component (does not spread props). SVG icons use
        # fill="currentColor" and inherit the CSS color from the wrapper.
        "{#{prop} && <span style={{display: \"inline-flex\", #{style_pairs}}}><#{prop}#{icon_style} /></span>}"
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

    def emit_detached_ref(ir)
      component_name = ir[:component_name]
      props_string = ir[:props_parts].empty? ? "" : " " + ir[:props_parts].join(" ")

      if ir[:swap_component_name]
        swap = ir[:swap_component_name]
        "{#{swap} ? <#{swap}#{props_string} /> : <#{component_name}#{props_string} />}"
      else
        "<#{component_name}#{props_string} />"
      end
    end

    def emit_detached_svg(ir)
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]

      safe_svg = ir[:svg_content].to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      clean_svg = safe_svg
        .gsub(/<\?xml[^>]*\?>/, "")
        .gsub(/xmlns="[^"]*"/, "")
        .gsub(/class="/, "className=\"")
        .strip

      "<div className=\"#{class_name}\" dangerouslySetInnerHTML={{__html: `#{clean_svg.gsub('`', '\\`')}`}} />"
    end

    def emit_figma_slot(ir)
      @has_slot = true
      class_name = generate_class_name(ir[:name], false)
      @css_rules[class_name] = ir[:styles]
      "<div className=\"#{class_name}\">{props.#{ir[:prop_name]}}</div>"
    end

    def emit_slot(ir)
      @has_slot = true
      "{props.#{ir[:prop_name]}}"
    end
  end
end
