module Renderable
  extend ActiveSupport::Concern
  include ComponentNaming

  private

  def render_figma_files(libraries)
    browser_code_parts = []
    css_parts = []
    loaded_react_names = Set.new
    container_names = Set.new

    # Load custom (upload) components first so they are defined early,
    # before potentially large Figma-generated code blocks.
    libraries.each do |cl|
      cl.components.where(source: "upload").where.not(react_code_compiled: [nil, ""]).each do |comp|
        react_name = to_component_name(comp.name)
        next if loaded_react_names.include?(react_name)
        browser_code_parts << comp.react_code_compiled
        loaded_react_names << react_name
        container_names << react_name if comp.slots.present? && comp.slots.any?
      end
    end

    libraries.each do |cl|
      cl.component_sets.includes(:variants).each do |cs|
        variant = cs.default_variant
        next unless variant&.react_code_compiled.present?
        react_name = to_component_name(cs.name)
        next if loaded_react_names.include?(react_name)
        browser_code_parts << variant.react_code_compiled
        loaded_react_names << react_name
        container_names << react_name if cs.slots.present? && cs.slots.any?
      end

      cl.components.where.not(react_code_compiled: [nil, ""]).each do |comp|
        react_name = to_component_name(comp.name)
        next if loaded_react_names.include?(react_name)
        browser_code_parts << comp.react_code_compiled
        loaded_react_names << react_name
        container_names << react_name if comp.slots.present? && comp.slots.any?
      end

      cl.components.where.not(css_code: [nil, ""]).each do |comp|
        css_parts << comp.css_code
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

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://unpkg.com/react@18/umd/react.development.js" crossorigin></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js" crossorigin></script>
        <script src="https://unpkg.com/@babel/standalone/babel.min.js" crossorigin></script>
        <style>body{margin:0}#{all_css}</style>
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

          window.addEventListener('message', function(e) {
            if (!e.data || e.data.type !== 'render') return;
            try {
              var compiled = Babel.transform(e.data.jsx, { presets: ['react'] }).code.replace(/;\\s*$/, '');
              var element = new Function('React', 'return (' + compiled + ')')(React);
              root.render(element);
            } catch (err) {
              console.warn('[renderer] Render error:', String(err));
              root.render(React.createElement('pre', {style: {color: 'red'}, className: 'render-error', 'data-error': 'true'}, String(err)));
            }
          });

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
