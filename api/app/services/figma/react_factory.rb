module Figma
  class ReactFactory
    include Figma::StyleExtractor

    # Bump this when code generation logic changes to force recompilation
    # on next DS sync, even if Figma content is unchanged.
    CODEGEN_VERSION = 5

    def initialize(figma_file)
      @figma_file = figma_file
      @resolver = Figma::Resolver.new(figma_file)
      @generated = {}
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

      ir = @resolver.resolve_component_set(component_set)
      return nil unless ir

      emitter = Figma::Emitter.new(component_name, resolver: @resolver)

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

      emitter = Figma::Emitter.new(component_name, resolver: @resolver)
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
          entry[:variant_record].update!(react_code_compiled: compiled)
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
