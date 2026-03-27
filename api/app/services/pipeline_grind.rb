require "fileutils"
require "json"
require "base64"

class PipelineGrind
  PASS_THRESHOLD = 95.0
  OUTPUT_DIR = Rails.root.join("tmp", "pipeline_grind")

  def initialize(ds_name = nil, force: false)
    @ds = ds_name.present? ? DesignSystem.find_by!(name: ds_name) : DesignSystem.first
    @force = force
    @report = {
      design_system: @ds.name,
      started_at: Time.now.iso8601,
      finished_at: nil,
      figma_files: [],
      components: [],
      summary: {}
    }
  end

  def run
    setup_output_dir
    log "Pipeline Grind: #{@ds.name}"
    log "FigmaFiles: #{@ds.current_figma_files.count}"

    @ds.current_figma_files.each do |ff|
      process_figma_file(ff)
    end

    @report[:finished_at] = Time.now.iso8601
    write_summary
    write_report
    print_summary
  end

  # Quick test: regenerate + test up to 10 variants per component set.
  # If component_name given, test just that one. Otherwise test ALL component sets.
  def quick_test(component_name = nil)
    setup_output_dir
    @skip_ai = component_name.nil? # skip AI for full sweep, enable for single component
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    @ds.current_figma_files.each do |ff|
      @current_lookup_data ||= {}
      @current_lookup_data[ff.id] ||= Figma::ReactFactory.build_lookup_data(ff)

      # Regenerate
      factory = Figma::ReactFactory.new(ff)
      component_sets = if component_name
        cs = ff.component_sets.find_by(name: component_name)
        cs ? [cs] : []
      else
        ff.component_sets.includes(:variants).reject(&:vector?)
      end

      next if component_sets.empty?

      component_sets.each do |cs|
        factory.generate_component_set(cs)
      end
      factory.send(:batch_compile_and_persist)

      # Build renderer + open browser
      html = build_renderer_html(ff)
      renderer_path = OUTPUT_DIR.join("renderer_quick.html")
      File.write(renderer_path, html)
      @current_renderer_path = renderer_path
      close_browser # force reload with new compiled code

      results = []

      component_sets.each do |cs|
        safe_cs = cs.name.gsub(/[^a-zA-Z0-9_-]/, "_")

        # Pick up to 10 variants
        variants = cs.variants.reload.select { |v| v.react_code_compiled.present? }
        if variants.size > 10
          default = variants.find(&:is_default) || variants.first
          step = [variants.size / 9, 1].max
          sampled = (0...variants.size).step(step).map { |i| variants[i] }
          sampled.unshift(default) unless sampled.include?(default)
          variants = sampled.first(10).uniq
        end

        variants.each do |v|
          variant_label = v.name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
          dir = OUTPUT_DIR.join("components", safe_cs, variant_label)
          FileUtils.mkdir_p(dir)
          figma_path = dir.join("figma.png").to_s
          react_path = dir.join("react.png").to_s
          diff_path = dir.join("diff.png").to_s

          next unless File.exist?(figma_path)

          # Render
          scoped = v.react_code_compiled[/^var (\w+)\s*=/, 1]
          ok = render_via_renderer(scoped, {}, react_path)
          next unless ok

          # Diff
          flatten_alpha(figma_path)
          diff_result = Figma::VisualDiff.new(nil, output_dir: dir.to_s)
            .send(:pixel_diff, figma_path, react_path, diff_path)
          match = (100 - diff_result[:diff_percent]).round(2)

          # AI inspect if failing (skip for full sweep to save time)
          ai_issues = nil
          if match < PASS_THRESHOLD && !@skip_ai
            comp_path = build_comparison_image(figma_path, react_path, diff_path, dir.to_s)
            ai_issues = ai_inspect(comp_path, match)
          end

          status = match >= PASS_THRESHOLD ? "PASS" : "FAIL"
          results << { cs: cs.name, variant: v.name, match: match, status: status, ai_issues: ai_issues }
          log "  #{status} #{match}% #{cs.name} / #{v.name}"
          if ai_issues&.any?
            ai_issues.first(3).each { |i| log "    → #{i}" }
          end
        end
      end

      close_browser
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(1)
      pass = results.count { |r| r[:status] == "PASS" }
      log ""
      log "=" * 50
      log "QUICK: #{pass}/#{results.size} pass in #{elapsed}s"
      if results.any?
        avg = (results.sum { |r| r[:match] } / results.size).round(1)
        log "Average match: #{avg}%"
      end
      log "=" * 50
    end
  end

  # Pre-download all Figma screenshots with retry/backoff.
  # Run this first: rake pipeline:cache_figma[DS_name]
  def cache_figma_screenshots
    setup_output_dir
    log "Caching Figma screenshots for: #{@ds.name}"
    total = 0
    cached = 0
    failed = 0

    @ds.current_figma_files.each do |ff|
      ff.component_sets.includes(:variants).each do |cs|
        next if cs.vector?
        safe_cs = cs.name.gsub(/[^a-zA-Z0-9_-]/, "_")

        cs.variants.each do |v|
          next unless v.react_code_compiled.present?
          total += 1
          variant_label = v.name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
          dir = OUTPUT_DIR.join("components", safe_cs, variant_label)
          figma_path = dir.join("figma.png").to_s

          if File.exist?(figma_path)
            cached += 1
            next
          end

          FileUtils.mkdir_p(dir)
          begin
            fetched = Figma::VisualDiff.fetch_figma_screenshot(ff.figma_file_key, v.node_id, dir)
            if fetched
              FileUtils.mv(fetched, figma_path) unless fetched == figma_path
              flatten_alpha(figma_path)
              cached += 1
              log "  [#{cached}/#{total}] #{cs.name} / #{v.name}" if cached % 20 == 0
            else
              failed += 1
              log "  [skip] #{cs.name} / #{v.name} — no image"
            end
          rescue => e
            if e.message.include?("429") || e.message.include?("rate")
              log "  Rate limited at #{cached}/#{total}. Sleeping 30s..."
              sleep 30
              retry
            end
            failed += 1
            log "  [error] #{cs.name} / #{v.name}: #{e.message}"
          end
        end
      end

      ff.components.each do |comp|
        next if comp.vector? || !comp.react_code_compiled.present?
        total += 1
        safe_name = comp.name.gsub(/[^a-zA-Z0-9_-]/, "_")
        dir = OUTPUT_DIR.join("components", safe_name)
        figma_path = dir.join("figma.png").to_s

        if File.exist?(figma_path)
          cached += 1
          next
        end

        FileUtils.mkdir_p(dir)
        begin
          fetched = Figma::VisualDiff.fetch_figma_screenshot(ff.figma_file_key, comp.node_id, dir)
          if fetched
            FileUtils.mv(fetched, figma_path) unless fetched == figma_path
            flatten_alpha(figma_path)
            cached += 1
          else
            failed += 1
          end
        rescue => e
          if e.message.include?("429") || e.message.include?("rate")
            log "  Rate limited at #{cached}/#{total}. Sleeping 30s..."
            sleep 30
            retry
          end
          failed += 1
          log "  [error] #{comp.name}: #{e.message}"
        end
      end
    end

    log "Done: #{cached}/#{total} cached, #{failed} failed"
  end

  private

  def setup_output_dir
    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(OUTPUT_DIR.join("components"))
  end

  def process_figma_file(ff)
    log "Processing FigmaFile: #{ff.figma_file_name} (#{ff.figma_file_key})"
    @current_lookup_data ||= {}
    @current_lookup_data[ff.id] ||= Figma::ReactFactory.build_lookup_data(ff)

    ff_report = {
      name: ff.figma_file_name,
      figma_file_key: ff.figma_file_key,
      components_total: 0,
      components_passing: 0,
      components_failing: 0
    }

    # Build renderer HTML page with all components loaded
    renderer_html = build_renderer_html(ff)
    renderer_path = OUTPUT_DIR.join("renderer_#{ff.id}.html")
    File.write(renderer_path, renderer_html)
    @current_renderer_path = renderer_path

    ff.component_sets.includes(:variants).each do |cs|
      next if cs.vector?
      results = test_component_set(ff, cs)
      @report[:components] << results
      ff_report[:components_total] += 1
      ff_report[results[:status] == "pass" ? :components_passing : :components_failing] += 1
    end

    ff.components.each do |comp|
      next if comp.vector?
      results = test_component(ff, comp)
      @report[:components] << results
      ff_report[:components_total] += 1
      ff_report[results[:status] == "pass" ? :components_passing : :components_failing] += 1
    end

    @report[:figma_files] << ff_report
    close_browser
  end

  def build_renderer_html(ff)
    libraries = if ff.design_system
      ff.design_system.figma_files_for_version(ff.version)
    else
      [ff]
    end

    browser_code_parts = []
    loaded = Set.new

    aliases = [] # map clean PascalCase name → scoped var name

    libraries.each do |lib|
      lib.component_sets.includes(:variants).each do |cs|
        react_name = to_component_name(cs.name)
        next if loaded.include?(react_name)
        default_var_name = nil
        cs.variants.each do |v|
          next unless v.react_code_compiled.present?
          browser_code_parts << v.react_code_compiled
          # Track the default variant's scoped function name for aliasing
          if v.is_default || default_var_name.nil?
            scoped = v.react_code_compiled[/^var (\w+)\s*=/, 1]
            default_var_name = scoped if scoped
          end
        end
        # Create alias: window.Button = window.Button_cs_123__v0
        if default_var_name && default_var_name != react_name
          aliases << "if(typeof #{default_var_name}!=='undefined')window.#{react_name}=#{default_var_name};"
        end
        loaded << react_name
      end
      lib.components.each do |comp|
        react_name = to_component_name(comp.name)
        next if loaded.include?(react_name)
        browser_code_parts << comp.react_code_compiled if comp.react_code_compiled.present?
        loaded << react_name
      end
    end

    font_css = generate_font_css
    component_scripts = browser_code_parts.map { |code|
      safe = code.gsub("</script>", '<\\/script>')
      "<script>#{safe}</script>"
    }.join("\n")

    <<~HTML
      <!DOCTYPE html>
      <html><head>
        <meta charset="UTF-8">
        <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
        <style>
          #{font_css}
          body { margin: 0; padding: 16px; background: white; }
        </style>
      </head><body>
        <div id="root"></div>
        #{component_scripts}
        <script>#{aliases.join("\n")}</script>
        <script>
          var root = ReactDOM.createRoot(document.getElementById('root'));
          window.renderComponent = function(name, props) {
            var Comp = window[name];
            if (!Comp) {
              document.getElementById('root').innerHTML = '<div style="color:red">Component not found: ' + name + '</div>';
              return false;
            }
            root.render(React.createElement(Comp, props || {}));
            return true;
          };
        </script>
      </body></html>
    HTML
  end

  def generate_font_css
    font_dir = Rails.root.join("test", "fonts")
    return "" unless Dir.exist?(font_dir)

    weights = {
      "Thin" => 100, "ExtraLight" => 200, "Light" => 300,
      "Regular" => 400, "Medium" => 500, "SemiBold" => 600,
      "Bold" => 700, "ExtraBold" => 800, "Heavy" => 800, "Black" => 900
    }
    css = ""

    Dir.glob(font_dir.join("*")).select { |d| File.directory?(d) }.each do |family_dir|
      family_name = File.basename(family_dir)

      # Check for fonts.css first
      fonts_css_path = File.join(family_dir, "fonts.css")
      if File.exist?(fonts_css_path)
        raw = File.read(fonts_css_path)
        raw = raw.gsub(/url\("([^"]+)"\)/) do |match|
          url = $1
          url.start_with?("http", "file://") ? match : "url(\"file://#{File.join(family_dir, url)}\")"
        end
        css += raw + "\n"
        next
      end

      # Auto-generate from font files
      Dir.glob(File.join(family_dir, "*.{woff2,woff,ttf}")).each do |font_file|
        basename = File.basename(font_file, File.extname(font_file))
        weight = weights.find { |w, _| basename.include?(w) }&.last || 400
        style = basename.include?("Italic") ? "italic" : "normal"
        format = case File.extname(font_file)
                 when ".woff2" then "woff2"
                 when ".woff" then "woff"
                 when ".ttf" then "truetype"
                 end
        css += "@font-face { font-family: \"#{family_name}\"; src: url(\"file://#{font_file}\") format(\"#{format}\"); font-weight: #{weight}; font-style: #{style}; }\n"
      end
    end
    css
  end

  def to_component_name(name)
    base_name = name.to_s.split(",").first&.split("=")&.last || name.to_s
    base_name = base_name.strip
    return base_name if base_name.match?(/\A[A-Z][a-zA-Z0-9]*\z/)
    result = base_name
      .gsub(/[^a-zA-Z0-9\s_-]/, "")
      .split(/[\s_-]+/)
      .map(&:capitalize)
      .join
      .gsub(/^[0-9]+/, "")
    result.empty? ? "Component" : result
  end

  def test_component_set(ff, cs)
    safe_name = cs.name.gsub(/[^a-zA-Z0-9_-]/, "_")
    result = {
      name: cs.name,
      type: "component_set",
      node_id: cs.node_id,
      figma_file: ff.figma_file_name,
      variants_total: 0,
      variants_tested: 0,
      variants: [],
      status: "pass"
    }

    cs.variants.each do |variant|
      next unless variant.react_code_compiled.present?
      vr = test_variant(ff, variant, safe_name, component_set: cs)
      result[:variants] << vr
      result[:variants_total] += 1
      result[:variants_tested] += 1
    end

    worst = result[:variants].min_by { |v| v[:match_percent] || 100 }
    result[:status] = (worst.nil? || (worst[:match_percent] || 100) >= PASS_THRESHOLD) ? "pass" : "fail"
    result
  end

  def test_component(ff, comp)
    safe_name = comp.name.gsub(/[^a-zA-Z0-9_-]/, "_")
    dir = OUTPUT_DIR.join("components", safe_name)

    result = {
      name: comp.name,
      type: "component",
      node_id: comp.node_id,
      figma_file: ff.figma_file_name,
      variants_total: 0,
      variants_tested: 0,
      variants: [],
      status: "pass"
    }

    return result unless comp.react_code_compiled.present?

    vr = run_comparison(ff.figma_file_key, comp.node_id, comp.react_code_compiled,
                        comp.name, dir, comp, figma_file: ff,
                        component_set: nil, component: comp)
    result[:variants] << vr
    result[:variants_total] = 1
    result[:variants_tested] = 1
    result[:status] = (vr[:match_percent] && vr[:match_percent] >= PASS_THRESHOLD) ? "pass" : "fail"
    result
  end

  def test_variant(ff, variant, component_safe_name, component_set: nil)
    variant_label = variant.name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
    dir = OUTPUT_DIR.join("components", component_safe_name, variant_label)

    run_comparison(ff.figma_file_key, variant.node_id, variant.react_code_compiled,
                   variant.name, dir, variant, figma_file: ff,
                   component_set: component_set, component: nil)
  end

  def run_comparison(file_key, node_id, compiled_code, label, dir, record,
                     figma_file: nil, component_set: nil, component: nil)
    FileUtils.mkdir_p(dir)
    figma_path = dir.join("figma.png").to_s
    react_path = dir.join("react.png").to_s
    diff_path = dir.join("diff.png").to_s
    ai_path = dir.join("ai_issues.txt").to_s
    diag_path = dir.join("diagnostics.json").to_s

    # Resumable: skip already-processed if not forced
    if !@force && File.exist?(figma_path) && File.exist?(react_path) && File.exist?(diff_path)
      match_pct = record.match_percent
      ai_issues = File.exist?(ai_path) ? File.read(ai_path).lines.map(&:strip).reject(&:empty?) : nil
      diagnostics = File.exist?(diag_path) ? JSON.parse(File.read(diag_path), symbolize_names: true) : nil
      log "  [cached] #{label} — #{match_pct}%"
      return build_variant_result(label, match_pct, figma_path, react_path, diff_path, ai_issues, diagnostics)
    end

    # 1. Fetch Figma screenshot (skip if already cached)
    unless File.exist?(figma_path)
      begin
        fetched = Figma::VisualDiff.fetch_figma_screenshot(file_key, node_id, dir)
        if fetched
          FileUtils.mv(fetched, figma_path) unless fetched == figma_path
          flatten_alpha(figma_path)
        end
      rescue => e
        log "  [error] Figma screenshot for #{label}: #{e.message}"
      end
    end

    unless File.exist?(figma_path)
      log "  [skip] #{label} — no Figma screenshot"
      return build_variant_result(label, nil, nil, nil, nil, nil, nil)
    end

    # 2. Render React screenshot via full renderer page
    render_failed = false
    begin
      # For standalone components, use the component name directly.
      # For multi-variant component set variants, use the scoped var name from compiled code.
      if component
        render_name = to_component_name(component.name)
      elsif component_set && record.respond_to?(:react_code_compiled) && record.react_code_compiled.present?
        # Extract the var name from compiled code (e.g. "var Button_cs_123__v0 = function")
        scoped_name = record.react_code_compiled[/^var (\w+)\s*=/, 1]
        render_name = scoped_name || to_component_name(component_set.name)
      else
        render_name = to_component_name(label)
      end

      rendered = render_via_renderer(render_name, {}, react_path)
      render_failed = !rendered
    rescue => e
      log "  [error] React render for #{label}: #{e.message}"
      render_failed = true
    end

    unless File.exist?(react_path)
      log "  [skip] #{label} — React render failed"
      diagnostics = run_diagnostics(record, figma_file, component_set, component, render_failed: true)
      File.write(diag_path, JSON.pretty_generate(diagnostics)) if diagnostics
      return build_variant_result(label, nil, figma_path, nil, nil, nil, diagnostics)
    end

    # 3. Pixel diff (flatten Figma transparent bg onto white first)
    match_pct = nil
    begin
      flatten_alpha(figma_path)
      diff_result = Figma::VisualDiff.new(nil, output_dir: dir).send(:pixel_diff, figma_path, react_path, diff_path)
      diff_pct = diff_result[:diff_percent]&.round(2)
      match_pct = diff_pct ? (100.0 - diff_pct).round(2) : nil
    rescue => e
      log "  [error] Pixel diff for #{label}: #{e.message}"
    end

    # 4. Update DB
    record.update!(match_percent: match_pct) if match_pct

    # 5. Diagnostics for failing components only
    diagnostics = nil
    if !match_pct || match_pct < PASS_THRESHOLD
      diagnostics = run_diagnostics(record, figma_file, component_set, component, render_failed: render_failed)
      File.write(diag_path, JSON.pretty_generate(diagnostics)) if diagnostics
    end

    # 6. AI inspection if below threshold
    ai_issues = nil
    if match_pct && match_pct < PASS_THRESHOLD
      comparison_path = build_comparison_image(figma_path, react_path, diff_path, dir)
      ai_issues = ai_inspect(comparison_path, match_pct)
      if ai_issues
        File.write(ai_path, ai_issues.join("\n"))
      end
    end

    status = match_pct && match_pct >= PASS_THRESHOLD ? "pass" : "fail"
    log "  [#{status}] #{label} — #{match_pct || '?'}%"

    build_variant_result(label, match_pct, figma_path, react_path, diff_path, ai_issues, diagnostics)
  end

  def build_variant_result(label, match_pct, figma_path, react_path, diff_path, ai_issues, diagnostics = nil)
    {
      name: label,
      match_percent: match_pct,
      status: (match_pct && match_pct >= PASS_THRESHOLD) ? "pass" : "fail",
      screenshots: {
        figma: figma_path,
        react: react_path,
        diff: diff_path
      },
      diagnostics: diagnostics,
      ai_issues: ai_issues
    }
  end

  def render_via_renderer(react_name, variant_props, output_path)
    ensure_browser_open

    props_json = variant_props.to_json
    success = @browser_page.evaluate("window.renderComponent(#{react_name.to_json}, #{props_json})")
    unless success
      log "    Component #{react_name} not found in renderer"
      return false
    end

    sleep 0.15 # wait for render (React renders synchronously, just need a frame for layout)

    # Try to screenshot the component element (has data-component attr), fall back to #root
    selector = @browser_page.evaluate(<<~JS)
      (function() {
        var el = document.querySelector('[data-component]');
        if (el && el.getBoundingClientRect().height > 0) return '[data-component]';
        var root = document.getElementById('root');
        if (root && root.firstElementChild && root.firstElementChild.getBoundingClientRect().height > 0)
          return '#root > *:first-child';
        return '#root';
      })()
    JS

    rect = @browser_page.evaluate("document.querySelector(#{selector.to_json}).getBoundingClientRect().toJSON()")
    if rect["height"].to_f < 1 || rect["width"].to_f < 1
      log "    #{react_name}: rendered element has 0 dimensions"
      return false
    end

    @browser_page.screenshot(path: output_path, selector: selector)
    true
  rescue => e
    log "    render_via_renderer error: #{e.message}"
    false
  end

  def ensure_browser_open
    return if @browser && @browser_page

    @browser&.quit rescue nil
    @browser = Ferrum::Browser.new(
      headless: true,
      window_size: [800, 600],
      browser_options: { "no-sandbox" => nil, "disable-setuid-sandbox" => nil }
    )
    @browser_page = @browser.create_page
    # Match Figma's 2x export scale
    @browser_page.command("Emulation.setDeviceMetricsOverride",
      width: 800, height: 600, deviceScaleFactor: 2, mobile: false)
    @browser_page.go_to("file://#{@current_renderer_path}")
    sleep 2 # wait for React + components to load
  end

  def close_browser
    @browser&.quit rescue nil
    @browser = nil
    @browser_page = nil
  end

  def run_diagnostics(record, figma_file, component_set, component, render_failed: false)
    diags = []

    # Stage 1: Import — does the record have figma_json?
    has_json = if component_set
      component_set.default_variant&.figma_json.present?
    elsif component
      component.figma_json.present?
    else
      record.respond_to?(:figma_json) && record.figma_json.present?
    end
    unless has_json
      diags << { stage: "import", status: "fail", message: "No figma_json — import incomplete" }
    end

    # Stage 2: Resolution — resolve and check for :unresolved nodes
    if has_json && figma_file
      begin
        lookup_data = @current_lookup_data&.dig(figma_file.id) || Figma::ReactFactory.build_lookup_data(figma_file)
        resolver = Figma::Resolver.new(lookup_data)
        ir = if component_set
          resolver.resolve_component_set(component_set)
        elsif component
          resolver.resolve_component(component)
        end

        if ir.nil?
          diags << { stage: "resolution", status: "fail", message: "Resolver returned nil" }
        else
          unresolved = count_unresolved(ir)
          if unresolved > 0
            diags << { stage: "resolution", status: "warn", message: "#{unresolved} unresolved instance(s)" }
          end

          # Stage 3: Emission — check JSX output
          begin
            component_name = resolver.send(:to_component_name, (component_set || component).name)
            emitter = Figma::Emitter.new(component_name)
            code = emitter.emit(ir)
            unless code.include?("data-component")
              diags << { stage: "emission", status: "fail", message: "No data-component attribute in emitted JSX" }
            end
            if code.include?("#FF69B4")
              diags << { stage: "emission", status: "warn", message: "Pink placeholder(s) in emitted JSX" }
            end
          rescue => e
            diags << { stage: "emission", status: "fail", message: "Emitter error: #{e.message}" }
          end
        end
      rescue => e
        diags << { stage: "resolution", status: "fail", message: "Resolver error: #{e.message}" }
      end
    end

    # Stage 4: Compilation
    unless record.react_code_compiled.present?
      diags << { stage: "compilation", status: "fail", message: "No compiled code" }
    end

    # Stage 5: Render
    if render_failed
      diags << { stage: "render", status: "fail", message: "Headless Chrome render produced no output or 0-height element" }
    end

    diags.empty? ? nil : diags
  end

  def count_unresolved(ir, count = 0)
    return count unless ir.is_a?(Hash)
    count += 1 if ir[:kind] == :unresolved
    (ir[:children] || []).each { |child| count = count_unresolved(child, count) }
    (ir[:tree] ? count_unresolved(ir[:tree], count) : count)
    if ir[:variants]
      ir[:variants].each { |v| count = count_unresolved(v, count) }
    end
    count
  end

  def flatten_alpha(png_path)
    img = ChunkyPNG::Image.from_file(png_path)
    white = ChunkyPNG::Image.new(img.width, img.height, ChunkyPNG::Color::WHITE)
    white.compose!(img)
    white.save(png_path)
  rescue => e
    log "  [warn] flatten_alpha failed: #{e.message}"
  end

  def build_comparison_image(figma_path, react_path, diff_path, dir)
    return nil unless File.exist?(figma_path) && File.exist?(react_path) && File.exist?(diff_path)

    figma = ChunkyPNG::Image.from_file(figma_path)
    react = ChunkyPNG::Image.from_file(react_path)
    diff = ChunkyPNG::Image.from_file(diff_path)

    w = [figma.width, react.width, diff.width].max
    h = [figma.height, react.height, diff.height].max

    comparison = ChunkyPNG::Image.new(w * 3, h, ChunkyPNG::Color::WHITE)
    comparison.compose!(figma, 0, 0)
    comparison.compose!(react, w, 0)
    comparison.compose!(diff, w * 2, 0)

    comp_path = File.join(dir, "comparison.png")
    comparison.save(comp_path)
    comp_path
  rescue => e
    log "  [warn] Comparison image failed: #{e.message}"
    nil
  end

  def ai_inspect(comparison_path, match_pct)
    return nil unless comparison_path && File.exist?(comparison_path)
    return nil unless ENV["OPENAI_API_KEY"].present?

    image_data = Base64.strict_encode64(File.binread(comparison_path))
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

    payload = {
      model: "gpt-4o",
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: "This is a side-by-side comparison of a UI component: LEFT = Figma design (reference), MIDDLE = React render (our generated code), RIGHT = pixel diff (red = different pixels).\n\nMatch: #{match_pct}%\n\nList every visual difference between LEFT and MIDDLE. Be specific: name the element, describe what's wrong (e.g. wrong color, missing padding, wrong border-radius). One line per issue. Ignore anti-aliasing artifacts."
          },
          {
            type: "input_image",
            image_url: "data:image/png;base64,#{image_data}"
          }
        ]
      }],
      max_output_tokens: 1000
    }

    raw = HTTP.auth("Bearer #{ENV.fetch('OPENAI_API_KEY')}")
      .post("https://api.openai.com/v1/responses", json: payload, ssl_context: ctx)
      .body.to_s
    parsed = JSON.parse(raw)
    text = parsed.dig("output", 0, "content", 0, "text") || parsed.dig("choices", 0, "message", "content")

    if text
      issues = text.strip.lines.map(&:strip).reject(&:empty?)
      log "  AI found #{issues.size} issues"
      issues
    end
  rescue => e
    log "  [warn] AI inspection failed: #{e.message}"
    nil
  end

  def write_report
    all_variants = @report[:components].flat_map { |c| c[:variants] }
    passing = all_variants.count { |v| v[:status] == "pass" }
    failing = all_variants.count { |v| v[:status] == "fail" }
    total = all_variants.size

    match_values = all_variants.filter_map { |v| v[:match_percent] }
    avg_match = match_values.any? ? (match_values.sum / match_values.size).round(1) : 0

    worst = all_variants
      .select { |v| v[:match_percent] }
      .sort_by { |v| v[:match_percent] }
      .first(10)
      .map { |v| { name: v[:name], match_percent: v[:match_percent] } }

    @report[:summary] = {
      total_components: @report[:components].size,
      total_variants: total,
      passing: passing,
      failing: failing,
      pass_rate: total > 0 ? (passing * 100.0 / total).round(1) : 0,
      avg_match: avg_match,
      worst: worst
    }

    File.write(OUTPUT_DIR.join("report.json"), JSON.pretty_generate(@report))
    log "Report written to #{OUTPUT_DIR.join('report.json')}"
  end

  def write_summary
    all_variants = @report[:components].flat_map { |c| c[:variants] }
    passing = all_variants.count { |v| v[:status] == "pass" }
    failing_variants = all_variants.select { |v| v[:status] == "fail" && v[:match_percent] }
      .sort_by { |v| v[:match_percent] }
    passing_names = all_variants.select { |v| v[:status] == "pass" }.map { |v| v[:name] }
    total = all_variants.size
    match_values = all_variants.filter_map { |v| v[:match_percent] }
    avg_match = match_values.any? ? (match_values.sum / match_values.size).round(1) : 0

    duration = if @report[:started_at] && @report[:finished_at]
      secs = Time.parse(@report[:finished_at]) - Time.parse(@report[:started_at])
      mins = (secs / 60).round
      mins >= 60 ? "#{mins / 60}h #{mins % 60}m" : "#{mins}m"
    else
      "?"
    end

    lines = []
    lines << "# Pipeline Grind Report — #{@ds.name}"
    lines << "**Date:** #{Date.today}"
    lines << "**Duration:** #{duration}"
    lines << "**Pass rate:** #{total > 0 ? (passing * 100.0 / total).round(1) : 0}% (#{passing}/#{total} variants)"
    lines << "**Average match:** #{avg_match}%"
    lines << ""

    # Stage breakdown
    all_diags = all_variants.flat_map { |v| v[:diagnostics] || [] }
    if all_diags.any?
      stage_counts = Hash.new { |h, k| h[k] = [] }
      all_diags.each do |d|
        stage_counts[d[:stage]] << d[:message]
      end

      lines << "## Stage breakdown"
      %w[import resolution emission compilation render].each do |stage|
        msgs = stage_counts[stage]
        if msgs.any?
          lines << "- **#{stage.capitalize}** issues: #{msgs.size} (#{msgs.first(3).join('; ')}#{'...' if msgs.size > 3})"
        else
          lines << "- **#{stage.capitalize}** issues: 0"
        end
      end
      diff_fails = all_variants.count { |v| v[:status] == "fail" && v[:match_percent] }
      lines << "- **Visual diff** failures: #{diff_fails} (below #{PASS_THRESHOLD}% match)"
      lines << ""
    end

    if failing_variants.any?
      lines << "## Failing components (#{failing_variants.size})"
      lines << ""
      failing_variants.each do |v|
        lines << "### #{v[:name]} — #{v[:match_percent]}%"
        if v[:diagnostics]&.any?
          v[:diagnostics].each { |d| lines << "- [#{d[:stage]}] #{d[:message]}" }
        end
        if v[:ai_issues]&.any?
          v[:ai_issues].each { |issue| lines << "- #{issue}" }
        elsif !v[:diagnostics]&.any?
          lines << "- No AI analysis available"
        end
        lines << ""
      end
    end

    if passing_names.any?
      lines << "## Passing components (#{passing_names.size})"
      lines << passing_names.join(", ")
      lines << ""
    end

    File.write(OUTPUT_DIR.join("summary.md"), lines.join("\n"))
  end

  def print_summary
    s = @report[:summary]
    log ""
    log "=" * 50
    log "SUMMARY: #{s[:pass_rate]}% pass rate (#{s[:passing]}/#{s[:total_variants]} variants)"
    log "Average match: #{s[:avg_match]}%"
    if s[:worst]&.any?
      log "Worst:"
      s[:worst].first(5).each { |w| log "  #{w[:name]} — #{w[:match_percent]}%" }
    end
    log "=" * 50
    log "Report: #{OUTPUT_DIR.join('report.json')}"
    log "Summary: #{OUTPUT_DIR.join('summary.md')}"
  end

  def log(message)
    puts "[PipelineGrind] #{message}"
  end
end
