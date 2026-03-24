module Figma
  class ReactFactory
    include Figma::StyleExtractor

    # Bump this when code generation logic changes to force recompilation
    # on next DS sync, even if Figma content is unchanged.
    CODEGEN_VERSION = 3

    def initialize(figma_file)
      @figma_file = figma_file
      @resolver = Figma::Resolver.new(figma_file)
      @generated = {}
      @figma = Figma::TokenPool.instance.primary_client
      @pending_compilations = []
      @pending_variant_compilations = []
      @batch_mode = false
    end

    def generate_all
      @batch_mode = true
      log "Starting React code generation for ComponentLibrary##{@figma_file.id}"

      log "Built lookup tables: #{@resolver.components_by_node_id.size} components, #{@resolver.component_sets_by_node_id.size} component sets, #{@resolver.variants_by_node_id.size} variants, #{@resolver.node_id_to_component_set.size} node mappings"
      log "SVG asset cache: #{@resolver.svg_assets_by_name.size} assets"
      log "Inline SVG cache: #{@resolver.inline_svgs_by_node_id.size} assets"

      component_sets = @figma_file.component_sets.to_a
      log "Generating React code for #{component_sets.size} component sets..."
      component_sets.each_with_index do |component_set, idx|
        @resolver.current_owner_node_id = component_set.node_id
        generate_component_set(component_set)
        log "  [#{idx + 1}/#{component_sets.size}] #{component_set.name}" if (idx + 1) % 10 == 0 || idx == component_sets.size - 1
      end

      components = @figma_file.components.to_a
      log "Generating React code for #{components.size} standalone components..."
      components.each_with_index do |component, idx|
        @resolver.current_owner_node_id = component.node_id
        generate_component(component)
        log "  [#{idx + 1}/#{components.size}] #{component.name}" if (idx + 1) % 10 == 0 || idx == components.size - 1
      end

      batch_compile_and_persist
      @resolver.save_unresolved_warnings

      log "React code generation complete! Generated #{@generated.size} components"
      @generated
    end

    def log(message)
      puts "[Figma::ReactFactory] #{message}"
    end

    def generate_component_set(component_set)
      return @generated[component_set.node_id] if @generated[component_set.node_id]

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
      svg_content = @resolver.svg_assets_by_name[normalized_name]

      if svg_content
        code = generate_svg_component_code(component_name, svg_content)
        compiled_code = defer_or_compile(code, component_name, "cs_#{component_set.id}", default_variant)
      else
        prop_definitions = component_set.prop_definitions || {}
        variant_prop_names = prop_definitions.select { |_, d| d["type"] == "VARIANT" }.keys
        all_variants = component_set.variants
          .select { |v| v.figma_json.present? }
          .sort_by { |v| [v.is_default ? 0 : 1, v.id] }

        if variant_prop_names.any? && all_variants.size > 1
          code = generate_multi_variant_code(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
          compiled_code = nil
        else
          node = default_variant.figma_json
          is_list = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")

          emitter = create_emitter(component_name, prop_definitions, node, is_list_component: is_list)

          instances, detached_nodes = @resolver.collect_instances(node)
          imports = @resolver.generate_imports(instances, detached_nodes)

          css_rules = {}
          jsx = emitter.generate_node(node, component_name, css_rules, 0, true)
          css = generate_css(css_rules)

          all_props = emitter_current_props(emitter).merge(emitter_nested_props(emitter))
          code = build_component_code(component_name, imports, css, jsx, all_props, has_slot: emitter.has_slot)
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

      prop_definitions = component.prop_definitions || {}
      is_list = component.name.include?("#list") || component.description.to_s.include?("#list")

      emitter = create_emitter(component_name, prop_definitions, node, is_list_component: is_list)

      instances, detached_nodes = @resolver.collect_instances(node)
      imports = @resolver.generate_imports(instances, detached_nodes)

      css_rules = {}
      jsx = emitter.generate_node(node, component_name, css_rules, 0, true)
      css = generate_css(css_rules)

      code = build_component_code(component_name, imports, css, jsx, emitter_current_props(emitter), has_slot: emitter.has_slot)

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

    # Create and configure an Emitter for a single component generation pass
    def create_emitter(component_name, prop_definitions, node, is_list_component: false)
      emitter = Figma::Emitter.new(component_name, resolver: @resolver)

      # Set up resolver mutable state for this pass
      @resolver.nested_instance_counters = {}
      @resolver.nested_instance_props = {}
      @resolver.is_list_component = is_list_component
      @resolver.prop_definitions = prop_definitions

      current_props = @resolver.extract_props(prop_definitions, node)
      slot_map = @resolver.build_slot_map(node, prop_definitions)
      @resolver.current_props = current_props

      @resolver.collect_nested_instance_props(node)

      emitter.configure(
        current_props: current_props,
        prop_definitions: prop_definitions,
        slot_map: slot_map,
        nested_instance_props: @resolver.nested_instance_props,
        is_list_component: is_list_component,
        rendered_list_slots: []
      )

      emitter
    end

    # Access current_props from an emitter (after generation)
    def emitter_current_props(emitter)
      emitter.instance_variable_get(:@current_props) || {}
    end

    # Access nested_instance_props from an emitter (after generation)
    def emitter_nested_props(emitter)
      emitter.instance_variable_get(:@nested_instance_props) || {}
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

      clean_svg = clean_svg
        .gsub(/fill="(?:#000(?:000)?|black|rgb\(0,\s*0,\s*0\))"/i, 'fill="currentColor"')
        .gsub(/stroke="(?:#000(?:000)?|black|rgb\(0,\s*0,\s*0\))"/i, 'stroke="currentColor"')

      w = clean_svg.match(/width="(\d+(?:\.\d+)?)"/)&.captures&.first
      h = clean_svg.match(/height="(\d+(?:\.\d+)?)"/)&.captures&.first
      style_obj = if w && h
        "{ width: '#{w}px', height: '#{h}px', flexShrink: 0 }"
      else
        "{ flexShrink: 0 }"
      end

      <<~CODE
        import React from 'react';

        const svg = `#{clean_svg.gsub('`', '\\`')}`;

        export function #{component_name}(props) {
          return (
            <div data-component="#{component_name}" style={#{style_obj}} dangerouslySetInnerHTML={{__html: svg}} {...props} />
          );
        }

        export default #{component_name};
      CODE
    end

    def generate_multi_variant_code(component_set, component_name, all_variants, variant_prop_names, prop_definitions)
      variant_entries = []
      all_imports = []

      all_variants.each_with_index do |variant, idx|
        node = variant.figma_json
        scope_id = "#{component_name.downcase.gsub(/[^a-z0-9]/, "")}v#{idx}"
        is_list = component_set.name.include?("#list") || component_set.description.to_s.include?("#list")

        emitter = create_emitter(component_name, prop_definitions, node, is_list_component: is_list)

        instances, detached_nodes = @resolver.collect_instances(node)
        imports = @resolver.generate_imports(instances, detached_nodes)
        all_imports << imports if imports.present?

        css_rules = {}
        jsx = emitter.generate_node(node, component_name, css_rules, 0, true)
        css = generate_css(css_rules)

        scoped_css = css.gsub(/^\.([a-z0-9_-]+)/i) { ".#{scope_id}-#{$1}" }
        scoped_jsx = jsx.gsub(/className="([^"]+)"/) { "className=\"#{scope_id}-#{$1}\"" }

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

        non_variant_props = emitter_current_props(emitter).merge(emitter_nested_props(emitter)).reject { |_, p| p[:type] == "VARIANT" }

        variant_entries << {
          index: idx,
          func_name: "#{component_name}__v#{idx}",
          css: scoped_css,
          jsx: scoped_jsx,
          variant_properties: variant.variant_properties,
          props: non_variant_props,
          has_slot: emitter.has_slot,
          is_default: variant.is_default,
          variant_record: variant,
          imports: imports
        }
      end

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

    def generate_variant_dispatch(component_name, variant_entries, variant_prop_names, prop_definitions)
      lines = []
      default_entry = variant_entries.find { |e| e[:is_default] } || variant_entries.first

      variant_entries.each do |entry|
        conditions = variant_prop_names.map do |prop_key|
          prop_name = @resolver.to_prop_name(prop_key.gsub(/#[\d:]+$/, "").strip)
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
        prop_name = @resolver.to_prop_name(clean_key)
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

    def defer_or_compile(code, component_name, component_id, record)
      record.update!(react_code: code)
      if @batch_mode
        @pending_compilations << { key: component_id, name: component_name, code: code, record: record }
        nil
      else
        compiled = compile_for_browser(code, component_name, component_id)
        record.update!(react_code_compiled: compiled)
        compiled
      end
    end

    def preprocess_for_browser(react_code, component_name, component_id, scope_id: nil)
      scope_id ||= component_id
      code = react_code.dup

      styles_var = "styles_#{scope_id}"
      code = code.gsub(/const styles = /, "const #{styles_var} = ")
      code = code.gsub(/\{styles\}/, "{#{styles_var}}")

      svg_var = "svg_#{scope_id}"
      code = code.gsub(/const svg = /, "const #{svg_var} = ")
      code = code.gsub(/\{__html: svg\}/, "{__html: #{svg_var}}")

      code = code.gsub(/\b#{Regexp.escape(component_name)}__v(\d+)\b/) { "#{component_name}_#{component_id}__v#{$1}" }

      code = code.gsub(/^import [^\n]+\n/, "")
      code = code.gsub(/^export default [^\n]+\n?/, "")
      code = code.gsub(/^export /, "")

      code
    end

    def postprocess_compiled(compiled)
      compiled = compiled.gsub(/^function (\w+)\(/, 'var \1 = function(')
      compiled.strip
    end

    def batch_compile_and_persist
      return if @pending_compilations.empty? && @pending_variant_compilations.empty?

      log "Batch-compiling #{@pending_compilations.size} components + #{@pending_variant_compilations.size} variants..."

      snippets = @pending_compilations.map do |entry|
        if entry[:code].blank?
          entry[:compiled] = "var #{entry[:name]} = function() { return React.createElement('div', null, 'No code generated'); }"
          nil
        else
          preprocessed = preprocess_for_browser(entry[:code], entry[:name], entry[:key])
          { key: entry[:key], code: preprocessed }
        end
      end.compact

      variant_snippets = @pending_variant_compilations.map do |entry|
        preprocessed = preprocess_for_browser(entry[:code], entry[:component_name], entry[:component_id], scope_id: entry[:key])
        { key: entry[:key], code: preprocessed }
      end

      compiled_map = Figma::JsxCompiler.compile_batch(snippets + variant_snippets)

      @pending_variant_compilations.each do |entry|
        raw = compiled_map[entry[:key]]
        if raw
          compiled = postprocess_compiled(raw)
          entry[:record].update!(react_code_compiled: compiled)
        else
          Rails.logger.error("Batch variant compilation missing output for #{entry[:name]}")
        end
      end

      @pending_compilations.each do |entry|
        compiled = entry[:compiled]
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

        gen = @generated.values.find { |g| g[:name] == entry[:name] }
        gen[:compiled_code] = compiled if gen
      end

      log "Batch compilation complete"
    end
  end
end
