module Renderable
  extend ActiveSupport::Concern
  include ComponentNaming

  private

  # Extract PascalCase component names referenced in code
  def extract_component_names(code)
    # Match JSX tags: <ComponentName and component references in props: {ComponentName}
    tags = code.scan(/<([A-Z][a-zA-Z0-9]*)[\s\/>]/).flatten
    refs = code.scan(/\{([A-Z][a-zA-Z0-9]*)\}/).flatten
    (tags + refs).to_set
  end

  # Extract prop values per component from JSX for variant matching
  # Returns { "Select" => [{"size"=>"M","state"=>"Default"}, {"size"=>"L","state"=>"Hover"}] }
  # Extract prop values from compiled code for transitively-discovered components.
  # Scans for React.createElement(ComponentName, { prop: "value" }) patterns.
  def extract_usages_from_compiled(react_name, browser_code_parts)
    usages = []
    pattern = /React\.createElement\(#{Regexp.escape(react_name)},\s*\{([^}]{0,500})\}/

    browser_code_parts.each do |code|
      code.scan(pattern).each do |match|
        props_str = match[0]
        props = {}
        # Extract key: "value" pairs
        props_str.scan(/(\w+):\s*"([^"]*)"/).each { |k, v| props[k] = v }
        usages << props if props.any?
      end
    end

    usages.uniq
  end

  def extract_component_usages(jsx)
    usages = {}
    jsx.scan(/<([A-Z][a-zA-Z0-9]*)\s+([^>]*?)\/?>/).each do |name, attrs|
      props = {}
      attrs.scan(/(\w+)="([^"]*)"/).each { |k, v| props[k] = v }
      usages[name] ||= []
      usages[name] << props unless props.empty?
    end
    usages
  end

  # Pre-compile JSX to React.createElement calls using esbuild
  def precompile_jsx(jsx)
    return nil if jsx.blank?
    compiled = Figma::JsxCompiler.compile(jsx)
    compiled.strip.gsub(/;\s*\z/, "")
  rescue => e
    Rails.logger.warn("[renderer] JSX precompile failed: #{e.message}")
    nil
  end

  # Try to load only the needed variants for a component set.
  # Returns true if per-variant code was available and loaded, false to fall back to full blob.
  def try_load_per_variant(cs, react_name, variant_prop_names, usages, browser_code_parts, css_parts = nil)
    all_variants = cs.variants.to_a.select { |v| v.figma_json.present? }
    non_default_with_code = all_variants.select { |v| !v.is_default && v.react_code_compiled.present? }
    return false if non_default_with_code.empty?

    component_id = "cs_#{cs.id}"
    default_variant = all_variants.find(&:is_default) || all_variants.first

    if usages.nil? || usages.empty?
      # No direct usage in JSX — infer from compiled code of already-loaded components
      usages = extract_usages_from_compiled(react_name, browser_code_parts)
    end

    if usages.nil? || usages.empty?
      # No usage info — load all variants (DS preview or component used without props)
      matched = Set.new(all_variants.select { |v| v.react_code_compiled.present? })
    else
      # Find which variants match the JSX prop values
      matched = Set.new
      matched << default_variant if default_variant.react_code_compiled.present?

      usages.each do |usage_props|
        best_score = 0
        best_variant = nil

        all_variants.each do |v|
          next unless v.react_code_compiled.present?
          vprops = v.variant_properties
          score = 0
          mismatch = false

          variant_prop_names.each do |prop_key|
            clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
            camel_name = to_prop_name(clean_key)
            usage_val = usage_props[camel_name]
            next unless usage_val
            if vprops[clean_key.downcase]&.downcase == usage_val.downcase
              score += 1
            else
              mismatch = true
            end
          end

          matched << v if !mismatch && score > 0
          # Track best partial match as fallback
          if score > best_score
            best_score = score
            best_variant = v
          end
        end

        # Fallback: if no exact match, use the best partial match
        matched << best_variant if matched.size <= 1 && best_variant && best_score > 0
      end
    end

    # Load per-variant compiled code and extract baked-in variant indices
    variant_baked_index = {}
    matched.each do |v|
      next unless v.react_code_compiled.present?
      browser_code_parts << v.react_code_compiled
      css_parts << v.css_code if css_parts && v.css_code.present?
      # Extract the baked-in index from the compiled function name (e.g. Button_cs_123__v42)
      if (m = v.react_code_compiled.match(/#{Regexp.escape(react_name)}_#{Regexp.escape(component_id)}__v(\d+)/))
        variant_baked_index[v.id] = m[1].to_i
      end
    end

    # Generate a minimal dispatcher function
    # Avoid destructuring variant props that collide with reserved React prop names
    # (e.g. Figma "style" variant prop vs React's CSS style prop).
    reserved_props = %w[style className key ref children].to_set

    safe_props = []
    collision_preamble = []
    variant_prop_names.each do |prop_key|
      clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
      prop_name = to_prop_name(clean_key)
      default_val = (cs.prop_definitions || {})[prop_key]&.dig("defaultValue") ||
                    default_variant.variant_properties[clean_key.downcase]
      if reserved_props.include?(prop_name)
        # Don't destructure — read from props without removing it
        safe_var = "__v_#{prop_name}"
        collision_preamble << "  var #{safe_var} = typeof props.#{prop_name} === \"string\" ? props.#{prop_name} : \"#{default_val}\";"
      else
        safe_props << "#{prop_name} = \"#{default_val}\""
      end
    end

    # Build default values map for comparison
    default_values = {}
    variant_prop_names.each do |prop_key|
      clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
      default_values[clean_key.downcase] = (cs.prop_definitions || {})[prop_key]&.dig("defaultValue")&.downcase
    end

    # Sort non-default variants first (most specific), default last
    dispatch_lines = matched.sort_by { |v| [v.is_default ? 1 : 0, v.id] }.map do |v|
      idx = variant_baked_index[v.id]
      next nil unless idx
      func_name = "#{react_name}_#{component_id}__v#{idx}"
      conditions = variant_prop_names.map do |prop_key|
        clean_key = prop_key.gsub(/#[\d:]+$/, "").strip
        prop_name = to_prop_name(clean_key)
        value = v.variant_properties[clean_key.downcase]
        next nil unless value
        # Only include condition for props that differ from default —
        # this allows partial matching when the AI omits or changes other props
        next nil if value.downcase == default_values[clean_key.downcase]
        var_name = reserved_props.include?(prop_name) ? "__v_#{prop_name}" : prop_name
        "#{var_name} === \"#{value}\""
      end.compact
      next nil if conditions.empty?
      "  if (#{conditions.join(' && ')}) return #{func_name}(props);"
    end.compact

    default_idx = variant_baked_index[default_variant.id]
    return false unless default_idx
    default_func = "#{react_name}_#{component_id}__v#{default_idx}"
    dispatch_lines << "  return #{default_func}(props);"

    body_lines = collision_preamble + dispatch_lines
    destructuring = safe_props.any? ? "{ #{safe_props.join(', ')}, ...props }" : "props"
    dispatcher = "var #{react_name} = function(#{destructuring}) {\n#{body_lines.join("\n")}\n};"
    browser_code_parts << dispatcher
    true
  end

  def render_figma_files(libraries, only: nil, precompiled_jsx: nil, component_usages: nil)
    browser_code_parts = []
    css_parts = []
    loaded_react_names = Set.new
    container_names = Set.new

    # Load a component set using per-variant code if available, otherwise full blob
    load_component_set = ->(cs, react_name) {
      return if loaded_react_names.include?(react_name)
      return if only && !only.include?(react_name)

      container_names << react_name if cs.slots.present? && cs.slots.any?

      # Check if per-variant compiled code exists
      variant_prop_names = (cs.prop_definitions || {}).select { |_, d| d["type"] == "VARIANT" }.keys
      has_per_variant = variant_prop_names.any? && cs.variants.where(is_default: false).where.not(react_code_compiled: [nil, ""]).exists?

      if has_per_variant
        usages = component_usages&.dig(react_name)
        if try_load_per_variant(cs, react_name, variant_prop_names, usages, browser_code_parts, css_parts)
          loaded_react_names << react_name
          return
        end
      end

      # Fallback: load full blob from default variant
      variant = cs.default_variant
      return unless variant&.react_code_compiled.present?
      browser_code_parts << variant.react_code_compiled
      css_parts << variant.css_code if variant.css_code.present?
      loaded_react_names << react_name
    }

    load_component = ->(comp, react_name) {
      return if loaded_react_names.include?(react_name)
      return if only && !only.include?(react_name)
      return unless comp.react_code_compiled.present?
      browser_code_parts << comp.react_code_compiled
      css_parts << comp.css_code if comp.css_code.present?
      loaded_react_names << react_name
      container_names << react_name if comp.slots.present? && comp.slots.any?
    }

    # Sort libraries: load complex components first, icon libraries last
    # This prevents icon SVG components from shadowing full widget components with the same name
    sorted_libs = libraries.sort_by { |cl| cl.components.count > 0 ? 0 : 1 }

    sorted_libs.each do |cl|
      cl.components.where(source: "upload").where.not(react_code_compiled: [nil, ""]).each do |comp|
        load_component.(comp, to_component_name(comp.name))
      end
      cl.component_sets.each do |cs|
        load_component_set.(cs, to_component_name(cs.name))
      end
      cl.components.where.not(react_code_compiled: [nil, ""]).each do |comp|
        load_component.(comp, to_component_name(comp.name))
      end
    end

    # Resolve transitive dependencies: scan loaded code for createElement refs
    if only
      resolved = Set.new
      loop do
        new_refs = Set.new
        browser_code_parts.each do |code|
          # Match React.createElement(ComponentName) calls
          code.scan(/React\.createElement\(([A-Z][a-zA-Z0-9]*)/).flatten.each do |ref|
            new_refs << ref unless loaded_react_names.include?(ref) || resolved.include?(ref)
          end
          # Match bare component references in prop values (e.g. StartIconComponent: Plus)
          code.scan(/Component:\s*([A-Z][a-zA-Z0-9]*)/).flatten.each do |ref|
            new_refs << ref unless loaded_react_names.include?(ref) || resolved.include?(ref)
          end
          # Match window.ComponentName references (from preprocessed imports)
          code.scan(/Component:\s*window\.([A-Z][a-zA-Z0-9]*)/).flatten.each do |ref|
            new_refs << ref unless loaded_react_names.include?(ref) || resolved.include?(ref)
          end
          # Match component default values in destructuring (e.g. StartIconComponent = Plus)
          code.scan(/Component\s*=\s*([A-Z][a-zA-Z0-9]*)/).flatten.each do |ref|
            new_refs << ref unless loaded_react_names.include?(ref) || resolved.include?(ref)
          end
          # Match window.ComponentName in default values
          code.scan(/Component\s*=\s*window\.([A-Z][a-zA-Z0-9]*)/).flatten.each do |ref|
            new_refs << ref unless loaded_react_names.include?(ref) || resolved.include?(ref)
          end
        end
        break if new_refs.empty?
        resolved.merge(new_refs)
        only.merge(new_refs)
        libraries.each do |cl|
          cl.component_sets.each do |cs|
            react_name = to_component_name(cs.name)
            next unless new_refs.include?(react_name)
            load_component_set.(cs, react_name)
          end
          cl.components.where.not(react_code_compiled: [nil, ""]).each do |comp|
            load_component.(comp, to_component_name(comp.name)) if new_refs.include?(to_component_name(comp.name))
          end
        end
      end
    end

    all_css = css_parts.join("\n")
    container_names_json = container_names.to_a.to_json

    # Each component gets its own <script> tag so a syntax error in one
    # AI-generated component cannot prevent other components from loading.
    component_scripts = browser_code_parts.map { |code|
      safe_code = code.gsub("</script>", '<\\/script>')
      "<script>#{safe_code}</script>"
    }.join("\n")

    precompiled_safe = precompiled_jsx&.gsub("</script>", '<\\/script>') || ""

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://unpkg.com/react@18/umd/react.production.min.js" crossorigin></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js" crossorigin></script>
        <style>
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Thin.ttf"); font-weight: 100; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Thin Italic.ttf"); font-weight: 100; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Light.ttf"); font-weight: 300; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Light Italic.ttf"); font-weight: 300; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Regular.ttf"); font-weight: 400; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Regular Italic.ttf"); font-weight: 400; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Medium.ttf"); font-weight: 500; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Medium Italic.ttf"); font-weight: 500; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Bold.ttf"); font-weight: 700; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Bold Italic.ttf"); font-weight: 700; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Heavy.ttf"); font-weight: 800; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Heavy Italic.ttf"); font-weight: 800; font-style: italic; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Black.ttf"); font-weight: 900; font-style: normal; }
          @font-face { font-family: "YS Text"; src: url("/fonts/YS%20Text-Black Italic.ttf"); font-weight: 900; font-style: italic; }
          body{margin:0;scrollbar-width:none}body::-webkit-scrollbar{display:none}#root>*{margin:0 auto}#{all_css}
        </style>
      </head>
      <body>
        <div id="root"></div>
        #{component_scripts}
        <script>
          // Slot component: groups children under a name for multi-slot components
          window.Slot = function Slot(props) {
            return props.children || null;
          };

          // Wrap container components to forward slot content
          var _containers = #{container_names_json};
          _containers.forEach(function(name) {
            if (window[name]) {
              var Orig = window[name];
              window[name] = function(props) {
                if (!props || !props.children) return Orig(props);

                // Extract named slots from children
                var slotProps = {};
                var defaultChildren = [];
                var kids = Array.isArray(props.children) ? props.children : [props.children];

                kids.forEach(function(child) {
                  if (child && child.type === Slot && child.props && child.props.name) {
                    var slotName = child.props.name;
                    // Store under original, camelCase, and lowercase for prop matching
                    slotProps[slotName] = child.props.children;
                    slotProps[slotName.toLowerCase()] = child.props.children;
                    var camelName = slotName.charAt(0).toLowerCase() + slotName.slice(1);
                    if (camelName !== slotName) slotProps[camelName] = child.props.children;
                  } else {
                    defaultChildren.push(child);
                  }
                });

                // Merge: named slots as props, unslotted children as props.children
                var merged = Object.assign({}, props, slotProps);
                if (defaultChildren.length > 0) {
                  merged.children = defaultChildren.length === 1 ? defaultChildren[0] : defaultChildren;
                } else {
                  delete merged.children;
                }

                return Orig(merged);
              };
              window[name].displayName = name;
            }
          });
        </script>
        <script>
          var root = ReactDOM.createRoot(document.getElementById('root'));

          function renderJsx(compiled) {
            try {
              var element = new Function('React', 'return (' + compiled + ')')(React);
              root.render(element);
              requestAnimationFrame(function() {
                setTimeout(function() {
                  var el = document.getElementById('root');
                  window.parent.postMessage({ type: 'resize', height: el.scrollHeight, width: el.scrollWidth }, '*');
                }, 50);
              });
            } catch (err) {
              console.warn('[renderer] Render error:', String(err));
              root.render(React.createElement('pre', {style: {color: 'red'}, className: 'render-error', 'data-error': 'true'}, String(err)));
            }
          }

          // Pre-compiled initial render (no Babel needed)
          var _precompiled = #{precompiled_safe.present? ? precompiled_safe.to_json : "null"};
          if (_precompiled) renderJsx(_precompiled);

          // Handle live JSX updates via postMessage (uses Babel, loaded async)
          window.addEventListener('message', function(e) {
            if (!e.data || e.data.type !== 'render') return;
            if (typeof Babel !== 'undefined') {
              var compiled = Babel.transform(e.data.jsx, { presets: ['react'] }).code.replace(/;\\s*$/, '');
              renderJsx(compiled);
            } else {
              // Queue until Babel loads
              window._pendingJsx = e.data.jsx;
            }
          });

          // Load Babel async for live editing
          var s = document.createElement('script');
          s.src = 'https://unpkg.com/@babel/standalone/babel.min.js';
          s.onload = function() {
            if (window._pendingJsx) {
              var compiled = Babel.transform(window._pendingJsx, { presets: ['react'] }).code.replace(/;\\s*$/, '');
              renderJsx(compiled);
              delete window._pendingJsx;
            }
          };
          document.head.appendChild(s);

          // Debug: log loaded component names
          var _loaded = #{loaded_react_names.to_a.to_json};
          var _missing = _loaded.filter(function(n) { return typeof window[n] === 'undefined'; });
          if (_missing.length > 0) {
            console.warn('[renderer] Missing components:', _missing.join(', '));
          }
          console.log('[renderer] Components loaded:', _loaded.length, 'missing:', _missing.length);
          window.parent.postMessage({ type: 'ready' }, '*');
        </script>
      </body>
      </html>
    HTML
  end
end
