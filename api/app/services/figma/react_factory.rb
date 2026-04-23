module Figma
  class ReactFactory
    include Figma::StyleExtractor

    # Bump this when code generation logic changes to force recompilation
    # on next DS sync, even if Figma content is unchanged.
    CODEGEN_VERSION = 7

    def initialize(figma_file)
      @figma_file = figma_file
      lookup_data = self.class.build_lookup_data(figma_file)
      @resolver = Figma::Resolver.new(lookup_data, figma_client: Figma::TokenPool.instance.primary_client)
      @generated = {}
      @pending_compilations = []
      @pending_variant_compilations = []
      @batch_mode = false
    end

    def self.normalize_icon_name(name)
      name.to_s.downcase
        .gsub(/\s+/, "-")
        .gsub(/[^a-z0-9-]/, "")
        .gsub(/-+/, "-")
        .gsub(/^-|-$/, "")
    end

    def self.build_lookup_data(figma_file)
      data = {
        components_by_node_id: {},
        component_sets_by_node_id: {},
        variants_by_node_id: {},
        node_id_to_component_set: {},
        component_key_by_node_id: figma_file.component_key_map || {},
        variants_by_component_key: {},
        svg_assets_by_name: {},
        inline_svgs_by_node_id: {},
        inline_pngs_by_node_id: {},
        image_component_keys: Set.new,
        figma_file_keys: Set.new,
      }

      sibling_files = if figma_file.design_system
        figma_file.design_system.figma_files_for_version(figma_file.version)
      else
        [figma_file]
      end

      sibling_files.each do |ff|
        ff.components.each do |component|
          data[:components_by_node_id][component.node_id] = component
        end

        ff.component_sets.includes(:variants).each do |cs|
          data[:component_sets_by_node_id][cs.node_id] = cs
          data[:figma_file_keys] << cs.figma_file_key if cs.figma_file_key.present?

          cs.variants.each do |v|
            data[:variants_by_node_id][v.node_id] = v
            data[:variants_by_component_key][v.component_key] = v if v.component_key.present?
            if v.figma_json.present?
              collect_all_node_ids(v.figma_json).each do |nid|
                data[:node_id_to_component_set][nid] = cs
              end
            end
          end
        end
      end

      # image_component_keys
      figma_file.component_sets.select(&:is_image).each do |cs|
        data[:image_component_keys] << cs.component_key if cs.component_key
        cs.variants.each { |v| data[:image_component_keys] << v.component_key if v.component_key }
      end
      figma_file.components.select(&:is_image).each do |c|
        data[:image_component_keys] << c.component_key if c.component_key
      end

      # svg_assets_by_name
      FigmaAsset.joins(:component)
        .where(components: { figma_file_id: figma_file.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component.name)
          data[:svg_assets_by_name][name] = asset.content if name.present?
        end
      FigmaAsset.joins(:component_set)
        .where(component_sets: { figma_file_id: figma_file.id })
        .where(asset_type: "svg")
        .each do |asset|
          name = normalize_icon_name(asset.component_set.name)
          data[:svg_assets_by_name][name] = asset.content if name.present?
        end

      # inline svgs/pngs
      component_ids = figma_file.components.pluck(:id)
      component_set_ids = figma_file.component_sets.pluck(:id)
      FigmaAsset.where(asset_type: %w[svg png])
        .where("node_id IS NOT NULL")
        .where(
          "component_id IN (?) OR component_set_id IN (?) OR (component_id IS NULL AND component_set_id IS NULL)",
          component_ids, component_set_ids
        )
        .find_each do |asset|
          if asset.asset_type == "png"
            data[:inline_pngs_by_node_id][asset.node_id] = asset.content
          else
            data[:inline_svgs_by_node_id][asset.node_id] = asset.content
          end
        end

      data
    end

    def self.collect_all_node_ids(node)
      return [] unless node.is_a?(Hash)
      ids = [node["id"]].compact
      (node["children"] || []).each { |child| ids += collect_all_node_ids(child) }
      ids
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
        if (idx + 1) % 5 == 0 || idx == component_sets.size - 1
          log "  [#{idx + 1}/#{component_sets.size}] #{component_set.name}"
          report("Codegen — #{idx + 1}/#{component_sets.size} sets: #{component_set.name}")
        end
      end

      components = @figma_file.components.to_a
      log "Generating React code for #{components.size} standalone components..."
      components.each_with_index do |component, idx|
        @resolver.current_owner_node_id = component.node_id
        generate_component(component)
        if (idx + 1) % 5 == 0 || idx == components.size - 1
          log "  [#{idx + 1}/#{components.size}] #{component.name}"
          report("Codegen — #{component_sets.size} sets done, #{idx + 1}/#{components.size} components: #{component.name}")
        end
      end

      report("Compiling #{@pending_compilations.size} components + #{@pending_variant_compilations.size} variants...")
      batch_compile_and_persist
      save_unresolved_warnings

      log "React code generation complete! Generated #{@generated.size} components"
      @generated
    end

    def log(message)
      puts "[Figma::ReactFactory] #{message}"
    end

    def report(message)
      @figma_file.update_progress(step: "converting", step_number: 3, total_steps: 4, message: message)
    end

    def generate_component_set(component_set)
      return @generated[component_set.node_id] if @generated[component_set.node_id]

      default_variant = component_set.default_variant
      return nil unless default_variant&.figma_json.present?

      component_name = to_component_name(component_set.name)

      ir = @resolver.resolve_component_set(component_set)
      return nil unless ir

      emitter = Figma::Emitter.new(component_name)

      if ir[:kind] == :multi_variant
        result = emitter.emit_multi_variant(ir)
        variant_entries = result[:variant_entries]
        all_imports = result[:all_imports]

        code = emit_and_compile_multi_variant(component_set, component_name, emitter, ir, variant_entries, all_imports)
        compiled_code = nil
      else
        code = emitter.emit(ir)
        compiled_code = defer_or_compile(code, component_name, "cs_#{component_set.id}", default_variant)
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

      ir = @resolver.resolve_component(component)
      return nil unless ir

      emitter = Figma::Emitter.new(component_name)
      code = emitter.emit(ir)

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

    def save_unresolved_warnings
      return if @resolver.unresolved_instances.empty?

      @resolver.unresolved_instances.each do |owner_node_id, instance_names|
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

      log "Added unresolved instance warnings to #{@resolver.unresolved_instances.size} components"
    end

    # Compile multi-variant entries and produce the combined component code
    def emit_and_compile_multi_variant(component_set, component_name, emitter, ir, variant_entries, all_imports)
      component_id = "cs_#{component_set.id}"

      variant_entries.each do |entry|
        per_variant_code = emitter.generate_per_variant_code(entry)

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
          js, css = split_css_from_compiled(compiled)
          entry[:variant_record].update!(react_code_compiled: js, css_code: css)
        end
      end

      emitter.build_variant_component_code(component_name, all_imports, variant_entries,
                                            ir[:variant_prop_names], ir[:prop_definitions])
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
        js, css = split_css_from_compiled(compiled)
        record.update!(react_code_compiled: js, css_code: css)
        js
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

      # Extract imported component names before stripping imports.
      # The renderer loads components as globals — declare them so esbuild
      # preserves references (e.g. StartIconComponent=Plus).
      imported_names = code.scan(/^import \{ (\w+) \} from/).flatten
      code = code.gsub(/^import [^\n]+\n/, "")
      code = code.gsub(/^export default [^\n]+\n?/, "")
      code = code.gsub(/^export /, "")

      # No additional transforms needed — imported component names are available
      # as globals in the renderer. esbuild preserves undefined references.

      code
    end

    def postprocess_compiled(compiled)
      compiled = compiled.gsub(/^function (\w+)\(/, 'var \1 = function(')
      compiled.strip
    end

    # Extract CSS from compiled JS: removes `const styles_X = \`...\`;` blocks
    # and `React.createElement("style", null, styles_X),` references from the
    # render output. Returns [js_without_style, extracted_css].
    def split_css_from_compiled(compiled)
      css_parts = []
      js = compiled.gsub(/const (styles_\w+)\s*=\s*`([\s\S]*?)`;\s*/) do
        css_parts << $2
        ""
      end
      # Strip the React.createElement("style", ...) calls. The trailing comma
      # is optional because the style tag might be the last child.
      js = js.gsub(/(?:\/\* @__PURE__ \*\/\s*)?React\.createElement\("style",\s*null,\s*styles_\w+\)\s*,\s*/, "")
      js = js.gsub(/(?:\/\* @__PURE__ \*\/\s*)?React\.createElement\("style",\s*null,\s*styles_\w+\)\s*/, "")
      [js.strip, css_parts.join("\n")]
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
          js, css = split_css_from_compiled(compiled)
          entry[:record].update!(react_code_compiled: js, css_code: css)
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

        js, css = split_css_from_compiled(compiled)
        entry[:record].update!(react_code_compiled: js, css_code: css)

        gen = @generated.values.find { |g| g[:name] == entry[:name] }
        gen[:compiled_code] = js if gen
      end

      log "Batch compilation complete"
    end
  end
end
