class FigmaFilesController < ApplicationController
  include ComponentNaming
  include Renderable

  before_action :require_auth, except: [:preview, :renderer, :components_list]

  def index
    figma_files = accessible_libraries
    render json: figma_files.map { |cl|
      {
        id: cl.id,
        name: cl.name,
        figma_url: cl.figma_url,
        figma_file_name: cl.figma_file_name,
        status: cl.status,
        progress: cl.progress,
        component_sets_count: cl.component_sets.count,
        components_count: cl.components.count
      }
    }
  end

  def show
    cl = FigmaFile.find(params[:id])
    render json: {
      id: cl.id,
      name: cl.name,
      figma_url: cl.figma_url,
      figma_file_key: cl.figma_file_key,
      figma_file_name: cl.figma_file_name,
      status: cl.status,
      progress: cl.progress,
      component_sets_count: cl.component_sets.count,
      components_count: cl.components.count
    }
  end

  def create
    url = params[:url] || params.dig(:figma_file, :url)
    name = params[:name] || params.dig(:figma_file, :name)

    # De-duplicate: find existing file for this Figma URL
    cl = current_user.figma_files.find_by(figma_url: url)
    if cl
      # Update name if provided and library has no name yet
      cl.update!(name: name) if name.present? && cl.name.blank?
      return render json: { id: cl.id, status: cl.status, figma_file_key: cl.figma_file_key }, status: :ok
    end

    attrs = { figma_url: url, name: name }
    cl = current_user.figma_files.create!(attrs)

    # Link to design system if provided
    ds_id = params[:design_system_id] || params.dig(:figma_file, :design_system_id)
    if ds_id.present?
      ds = current_user.design_systems.find(ds_id)
      cl.update!(design_system: ds, version: ds.version)
    end

    render json: { id: cl.id, status: cl.status, figma_file_key: cl.figma_file_key }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    cl = current_user.figma_files.find(params[:id])
    cl.update!(figma_file_params)
    render json: {
      id: cl.id,
      name: cl.name,
      is_public: cl.design_system&.is_public
    }
  end

  # GET /api/component-libraries/available
  # Returns user's own + all public libraries
  def available
    own = current_user.figma_files.to_a
    public_libs = FigmaFile.joins(:design_system).where(design_systems: { is_public: true }).where.not(user: current_user).to_a
    all_libs = (own + public_libs).uniq

    render json: all_libs.map { |cl|
      {
        id: cl.id,
        name: cl.name,
        figma_url: cl.figma_url,
        figma_file_name: cl.figma_file_name,
        status: cl.status,
        is_public: cl.design_system&.is_public,
        is_own: cl.user_id == current_user.id,
        component_sets_count: cl.component_sets.count,
        components_count: cl.components.count
      }
    }
  end

  # POST /api/figma-files/:id/sync
  # Always sync via design system
  def sync
    cl = find_accessible_library(params[:id])
    unless cl.design_system
      render json: { error: "Figma file must belong to a design system to sync" }, status: :unprocessable_entity
      return
    end
    new_version = cl.design_system.sync_async
    render json: { id: cl.id, status: cl.design_system.reload.status, progress: cl.design_system.progress }
  end

  # GET /api/component-libraries/:id/components
  # Returns all components with their status, match_percent, etc.
  def components_list
    cl = FigmaFile.find(params[:id])

    sets = cl.component_sets.includes(:variants).map do |cs|
      dv = cs.default_variant
      {
        id: cs.id,
        type: "component_set",
        name: cs.name,
        node_id: cs.node_id,
        figma_file_id: cl.id,
        is_vector: cs.vector?,
        is_root: cs.is_root,
        slots: cs.slots,
        figma_url: cs.figma_url,
        description: cs.description,
        prop_definitions: cs.prop_definitions,
        validation_warnings: cs.validation_warnings || [],
        react_name: to_component_name(cs.name),
        default_variant_react_code: dv&.react_code,
        default_variant_match_percent: dv&.match_percent,
        variants_count: cs.variants.size,
        variants: cs.variants.map { |v|
          {
            id: v.id,
            name: v.name,
            is_default: v.is_default,
            has_html: v.html_code.present?,
            has_react: v.react_code.present?,
            match_percent: v.match_percent
          }
        }
      }
    end

    components = cl.components.map do |c|
      {
        id: c.id,
        type: "component",
        name: c.name,
        node_id: c.node_id,
        figma_file_id: cl.id,
        is_vector: c.vector?,
        is_root: c.is_root,
        slots: c.slots,
        status: c.status,
        match_percent: c.match_percent,
        enabled: c.enabled,
        error_message: c.error_message,
        figma_url: c.figma_url,
        description: c.description,
        prop_definitions: c.prop_definitions,
        validation_warnings: c.validation_warnings || [],
        react_name: to_component_name(c.name),
        react_code: c.react_code,
        has_html: c.html_code.present?,
        has_react: c.react_code.present?
      }
    end

    render json: { component_sets: sets, components: components }
  end

  def preview
    @figma_file = FigmaFile.find(params[:id])

    # Get component sets with their default variants
    component_sets = @figma_file.component_sets.includes(:variants)

    # Get standalone components
    standalone_components = @figma_file.components.where.not(react_code: [nil, ""])

    # Build browser code from component sets (default variants) and standalone components
    all_browser_code = []

    component_sets.each do |cs|
      variant = cs.default_variant
      next unless variant&.react_code_compiled.present?
      all_browser_code << variant.react_code_compiled
    end

    standalone_components.each do |comp|
      next unless comp.react_code_compiled.present?
      all_browser_code << comp.react_code_compiled
    end

    all_browser_code = all_browser_code.join("\n\n")

    # Group by file for display
    items_by_file = {}

    component_sets.each do |cs|
      file_name = cs.figma_file_name || "Unknown"
      items_by_file[file_name] ||= []
      items_by_file[file_name] << { type: :component_set, item: cs }
    end

    standalone_components.each do |comp|
      file_name = comp.figma_file_name || "Unknown"
      items_by_file[file_name] ||= []
      items_by_file[file_name] << { type: :component, item: comp }
    end

    # Build component cards HTML
    component_cards = build_component_cards(items_by_file)

    total_count = component_sets.count + standalone_components.count

    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{ERB::Util.html_escape(@figma_file.name || "Figma File")} - Preview</title>
        <script src="https://unpkg.com/react@18/umd/react.development.js" crossorigin></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js" crossorigin></script>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f0f0f0;
            min-height: 100vh;
            padding: 24px;
          }
          .tabs {
            display: flex;
            gap: 8px;
            margin-top: 16px;
            flex-wrap: wrap;
          }
          .tab {
            padding: 8px 16px;
            border: none;
            background: #e0e0e0;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
            color: #555;
            transition: all 0.15s;
          }
          .tab:hover {
            background: #d0d0d0;
          }
          .tab.active {
            background: #1976d2;
            color: white;
          }
          .tab .count {
            margin-left: 6px;
            opacity: 0.7;
            font-weight: 400;
          }
          .file-section {
            display: none;
          }
          .file-section.visible {
            display: block;
          }
          .header {
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            padding: 24px;
            margin-bottom: 24px;
          }
          .header h1 {
            font-size: 24px;
            color: #111;
            margin-bottom: 8px;
          }
          .header p {
            font-size: 14px;
            color: #666;
          }
          .file-section {
            margin-bottom: 32px;
          }
          .file-header {
            font-size: 16px;
            font-weight: 600;
            color: #333;
            padding: 12px 16px;
            background: #e0e0e0;
            border-radius: 8px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
          }
          .file-header::before {
            content: "📁";
          }
          .components-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
            gap: 16px;
          }
          .component-card {
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            overflow: hidden;
          }
          .component-header {
            padding: 16px;
            border-bottom: 1px solid #eee;
          }
          .component-name {
            font-size: 16px;
            font-weight: 600;
            color: #111;
            margin-bottom: 4px;
          }
          .component-meta {
            font-size: 11px;
            color: #888;
            font-family: monospace;
          }
          .component-type {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 500;
            margin-top: 8px;
          }
          .component-type.set {
            background: #e3f2fd;
            color: #1565c0;
          }
          .component-type.component {
            background: #f3e5f5;
            color: #7b1fa2;
          }
          .component-type.vector {
            background: #e8f5e9;
            color: #2e7d32;
          }
          .svg-icon {
            max-width: 64px;
            max-height: 64px;
            width: auto;
            height: auto;
          }
          .variants-list {
            margin-top: 8px;
            padding-top: 8px;
            border-top: 1px dashed #eee;
          }
          .variant-item {
            font-size: 12px;
            color: #666;
            padding: 2px 0;
          }
          .variant-item::before {
            content: "├─ ";
            color: #ccc;
          }
          .component-preview {
            padding: 24px;
            background: #fafafa;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 120px;
            overflow: auto;
          }
          .component-preview > div {
            max-width: 100%;
          }
          .component-description {
            padding: 12px 16px;
            font-size: 13px;
            color: #555;
            background: #f9f9f9;
            border-top: 1px solid #eee;
          }
          .error-preview {
            color: #c62828;
            font-size: 12px;
            padding: 12px;
            background: #ffebee;
            border-radius: 4px;
          }
          .figma-link {
            font-size: 11px;
            color: #1976d2;
            text-decoration: none;
          }
          .figma-link:hover {
            text-decoration: underline;
          }
          .debug-section {
            border-top: 1px solid #eee;
          }
          .debug-section summary {
            padding: 10px 16px;
            font-size: 12px;
            color: #666;
            cursor: pointer;
            background: #f5f5f5;
          }
          .debug-section summary:hover {
            background: #eee;
          }
          .debug-section pre {
            margin: 0;
            padding: 12px 16px;
            font-size: 11px;
            background: #1e1e1e;
            color: #d4d4d4;
            overflow-x: auto;
            max-height: 400px;
            overflow-y: auto;
          }
          .debug-section .loading {
            padding: 12px 16px;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>#{ERB::Util.html_escape(@figma_file.name || "Figma File ##{@figma_file.id}")}</h1>
          <p>#{total_count} components loaded from Figma (#{component_sets.count} component sets, #{standalone_components.count} standalone)</p>
          <div class="tabs">
            <button class="tab active" data-file="all">All<span class="count">(#{total_count})</span></button>
            #{build_file_tabs(items_by_file)}
          </div>
        </div>

        #{component_cards}

        <script>
          #{all_browser_code}

          // Render each component into its container
          document.querySelectorAll('[data-component]').forEach(function(container) {
            var componentName = container.dataset.component;
            var Component = window[componentName];
            if (Component) {
              try {
                var root = ReactDOM.createRoot(container);
                root.render(React.createElement(Component, null));
              } catch (e) {
                container.innerHTML = '<div class="error-preview">Render error: ' + e.message + '</div>';
              }
            } else {
              container.innerHTML = '<div class="error-preview">Component not found: ' + componentName + '</div>';
            }
          });

          // Tab switching
          document.querySelectorAll('.tab').forEach(function(tab) {
            tab.addEventListener('click', function() {
              var file = this.dataset.file;

              // Update active tab
              document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); });
              this.classList.add('active');

              // Show/hide sections
              document.querySelectorAll('.file-section').forEach(function(section) {
                if (file === 'all' || section.dataset.file === file) {
                  section.classList.add('visible');
                } else {
                  section.classList.remove('visible');
                }
              });
            });
          });

          // Lazy-load Figma JSON on click
          document.querySelectorAll('.debug-section').forEach(function(details) {
            details.addEventListener('toggle', function() {
              if (!details.open) return;

              var pre = details.querySelector('pre');
              if (pre.dataset.loaded) return;

              var componentId = details.dataset.componentId;
              var componentSetId = details.dataset.componentSetId;
              pre.innerHTML = 'Loading...';

              var url;
              if (componentId) {
                url = '/api/components/' + componentId + '/figma_json';
              } else if (componentSetId) {
                url = '/api/component_sets/' + componentSetId + '/figma_json';
              } else {
                pre.textContent = 'No ID found';
                return;
              }

              fetch(url)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                  pre.textContent = JSON.stringify(data.figma_json, null, 2);
                  pre.dataset.loaded = 'true';
                })
                .catch(function(e) {
                  pre.textContent = 'Error loading: ' + e.message;
                });
            });
          });
        </script>
      </body>
      </html>
    HTML

    render html: html.html_safe, layout: false
  end

  # GET /api/component-libraries/:id/renderer
  # Self-contained HTML page for rendering JSX in an iframe via postMessage
  def renderer
    cl = FigmaFile.find(params[:id])
    html = render_figma_files([cl])
    render html: html.html_safe, layout: false
  end

  private

  def figma_file_params
    params.require(:figma_file).permit(:name)
  end

  def accessible_libraries
    current_user.figma_files
  end

  def find_accessible_library(id)
    # Owner's own files, or files belonging to a public design system
    current_user.figma_files.find_by(id: id) ||
      FigmaFile.joins(:design_system).where(design_systems: { is_public: true }).find(id)
  end

  def build_component_cards(items_by_file)
    items_by_file.map do |file_name, items|
      file_header = file_name || "Unknown File"

      cards = items.map do |item_data|
        if item_data[:type] == :component_set
          build_component_set_card(item_data[:item])
        else
          build_component_card(item_data[:item])
        end
      end.join("\n")

      file_key = items.first&.dig(:item)&.figma_file_key || "unknown"

      <<~HTML
        <div class="file-section visible" data-file="#{ERB::Util.html_escape(file_key)}">
          <div class="file-header">#{ERB::Util.html_escape(file_header)}</div>
          <div class="components-grid">
            #{cards}
          </div>
        </div>
      HTML
    end.join("\n")
  end

  def build_component_set_card(component_set)
    comp_name = to_component_name(component_set.name)
    is_vector = component_set.vector?
    type_class = is_vector ? "vector" : "set"
    type_label = is_vector ? "Vector" : "Component Set"

    # Get variants - show default first and bold
    variants_html = ""
    if component_set.variants.any?
      sorted_variants = component_set.variants.sort_by { |v| v.is_default ? 0 : 1 }
      variant_items = sorted_variants.first(5).map do |v|
        if v.is_default
          "<div class=\"variant-item\"><strong>#{ERB::Util.html_escape(v.name)} ★</strong></div>"
        else
          "<div class=\"variant-item\">#{ERB::Util.html_escape(v.name)}</div>"
        end
      end.join
      more = component_set.variants.size > 5 ? "<div class=\"variant-item\">... and #{component_set.variants.size - 5} more</div>" : ""
      variants_html = "<div class=\"variants-list\">#{variant_items}#{more}</div>"
    end

    description_html = ""
    if component_set.description.present?
      description_html = "<div class=\"component-description\">#{ERB::Util.html_escape(component_set.description)}</div>"
    end

    figma_link = ""
    if component_set.figma_url.present?
      figma_link = "<a href=\"#{ERB::Util.html_escape(component_set.figma_url)}\" target=\"_blank\" class=\"figma-link\">Open in Figma ↗</a>"
    end

    figma_json_html = <<~DEBUG
      <details class="debug-section" data-component-set-id="#{component_set.id}">
        <summary>Figma JSON (default variant)</summary>
        <pre></pre>
      </details>
    DEBUG

    preview_html = if is_vector
      asset = component_set.figma_assets.svgs.first
      if asset&.content.present?
        "<div class=\"svg-icon\">#{asset.content}</div>"
      else
        "<img class=\"svg-icon\" src=\"/api/component_sets/#{component_set.id}/svg\" alt=\"#{ERB::Util.html_escape(component_set.name)}\" loading=\"lazy\" />"
      end
    else
      "<div data-component=\"#{ERB::Util.html_escape(comp_name)}\"></div>"
    end

    <<~HTML
      <div class="component-card">
        <div class="component-header">
          <div class="component-name">#{ERB::Util.html_escape(component_set.name)}</div>
          <div class="component-meta">#{ERB::Util.html_escape(component_set.node_id)} #{figma_link}</div>
          <div class="component-type #{type_class}">#{type_label} (#{component_set.variants.size} variants)</div>
          #{variants_html}
        </div>
        <div class="component-preview">
          #{preview_html}
        </div>
        #{description_html}
        #{figma_json_html}
      </div>
    HTML
  end

  def build_component_card(comp)
    comp_name = to_component_name(comp.name)
    is_vector = comp.vector?
    type_class = is_vector ? "vector" : "component"
    type_label = is_vector ? "Vector" : "Component"

    description_html = ""
    if comp.description.present?
      description_html = "<div class=\"component-description\">#{ERB::Util.html_escape(comp.description)}</div>"
    end

    figma_link = ""
    if comp.figma_url.present?
      figma_link = "<a href=\"#{ERB::Util.html_escape(comp.figma_url)}\" target=\"_blank\" class=\"figma-link\">Open in Figma ↗</a>"
    end

    figma_json_html = <<~DEBUG
      <details class="debug-section" data-component-id="#{comp.id}">
        <summary>Figma JSON</summary>
        <pre></pre>
      </details>
    DEBUG

    preview_html = if is_vector
      "<img class=\"svg-icon\" src=\"/api/components/#{comp.id}/svg\" alt=\"#{ERB::Util.html_escape(comp.name)}\" loading=\"lazy\" />"
    else
      "<div data-component=\"#{ERB::Util.html_escape(comp_name)}\"></div>"
    end

    <<~HTML
      <div class="component-card">
        <div class="component-header">
          <div class="component-name">#{ERB::Util.html_escape(comp.name)}</div>
          <div class="component-meta">#{ERB::Util.html_escape(comp.node_id)} #{figma_link}</div>
          <div class="component-type #{type_class}">#{type_label}</div>
        </div>
        <div class="component-preview">
          #{preview_html}
        </div>
        #{description_html}
        #{figma_json_html}
      </div>
    HTML
  end

  def build_file_tabs(items_by_file)
    items_by_file.map do |file_name, items|
      file_key = items.first&.dig(:item)&.figma_file_key || "unknown"
      label = file_name || "Unknown"
      count = items.size
      "<button class=\"tab\" data-file=\"#{ERB::Util.html_escape(file_key)}\">#{ERB::Util.html_escape(label)}<span class=\"count\">(#{count})</span></button>"
    end.join("\n")
  end

end
