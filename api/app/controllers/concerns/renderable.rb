module Renderable
  extend ActiveSupport::Concern
  include ComponentNaming

  private

  # Extract PascalCase component names referenced in code
  def extract_component_names(code)
    code.scan(/<([A-Z][a-zA-Z0-9]*)[\s\/>]/).flatten.to_set
  end

  # Pre-compile JSX to React.createElement calls using esbuild
  def precompile_jsx(jsx)
    return nil if jsx.blank?
    compiled = Figma::JsxCompiler.compile(jsx)
    # esbuild wraps in module scope; strip trailing semicolons for eval
    compiled.strip.gsub(/;\s*\z/, "")
  rescue => e
    Rails.logger.warn("[renderer] JSX precompile failed: #{e.message}")
    nil
  end

  def render_figma_files(libraries, only: nil, precompiled_jsx: nil)
    browser_code_parts = []
    css_parts = []
    loaded_react_names = Set.new
    container_names = Set.new

    # Build index of all available components for dependency resolution
    all_components = {}
    libraries.each do |cl|
      cl.components.where(source: "upload").where.not(react_code_compiled: [nil, ""]).each do |comp|
        react_name = to_component_name(comp.name)
        all_components[react_name] ||= { code: comp.react_code_compiled, slots: comp.slots, css: nil }
      end
      cl.component_sets.includes(:variants).each do |cs|
        variant = cs.default_variant
        next unless variant&.react_code_compiled.present?
        react_name = to_component_name(cs.name)
        all_components[react_name] ||= { code: variant.react_code_compiled, slots: cs.slots, css: nil }
      end
      cl.components.where.not(react_code_compiled: [nil, ""]).each do |comp|
        react_name = to_component_name(comp.name)
        all_components[react_name] ||= { code: comp.react_code_compiled, slots: comp.slots, css: nil }
      end
      cl.components.where.not(css_code: [nil, ""]).each do |comp|
        react_name = to_component_name(comp.name)
        all_components[react_name] ||= { code: nil, slots: comp.slots, css: nil }
        all_components[react_name][:css] = comp.css_code
      end
    end

    # Resolve transitive dependencies if filtering
    if only
      needed = only.dup
      queue = needed.to_a
      while (name = queue.shift)
        entry = all_components[name]
        next unless entry
        # Scan compiled code for references to other components
        refs = entry[:code].scan(/React\.createElement\(([A-Z][a-zA-Z0-9]*)/).flatten
        refs.each do |ref|
          unless needed.include?(ref)
            needed << ref
            queue << ref
          end
        end
      end
      only = needed
    end

    # Load components (filtered if only is set)
    all_components.each do |react_name, entry|
      next if only && !only.include?(react_name)
      next if loaded_react_names.include?(react_name)
      browser_code_parts << entry[:code] if entry[:code]
      loaded_react_names << react_name
      container_names << react_name if entry[:slots].present? && entry[:slots].any?
      css_parts << entry[:css] if entry[:css]
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
        <style>body{margin:0;scrollbar-width:none}body::-webkit-scrollbar{display:none}#root>*{margin:0 auto}#{all_css}</style>
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
                    slotProps[child.props.name] = child.props.children;
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
