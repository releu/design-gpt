require "fileutils"
$stdout.sync = true

namespace :e2e do
  desc "Webmaster DS: import, generate, assert JSX, visual diff against Figma"
  task webmaster: :environment do
    OUTPUT_DIR = Rails.root.join("tmp", "e2e_webmaster")
    FileUtils.mkdir_p(OUTPUT_DIR)

    source_ds = DesignSystem.find(1)
    user = source_ds.user || User.first
    all_errors = []
    ds = nil
    designs = []

    puts "=== E2E Webmaster Test ==="

    # --- Step 1: Create fresh DS and import (parallel) ---
    ds = DesignSystem.create!(name: "E2E Webmaster #{Time.now.to_i}", user: user)
    puts "[1] Created DS ##{ds.id}"

    figma_files = source_ds.current_figma_files.map do |source_ff|
      ds.figma_files.create!(
        figma_file_key: source_ff.figma_file_key,
        figma_file_name: source_ff.figma_file_name || source_ff.figma_file_key,
        figma_url: source_ff.figma_url,
        user: user,
        version: ds.version,
        status: "pending"
      )
    end

    threads = figma_files.map do |ff|
      Thread.new do
        t0 = Time.now
        puts "  [thread] Importing #{ff.figma_file_key}..."
        Figma::Importer.new(ff).import
        puts "  [thread] #{ff.figma_file_key} imported in #{(Time.now - t0).round(1)}s, extracting assets..."
        Figma::AssetExtractor.new(ff).extract_all
        puts "  [thread] #{ff.figma_file_key} assets done in #{(Time.now - t0).round(1)}s, generating code..."
        Figma::ReactFactory.new(ff).generate_all
        ff.update!(status: "ready")
        puts "  [thread] #{ff.figma_file_key} done in #{(Time.now - t0).round(1)}s"
      end
    end
    threads.each(&:join)
    ds.update!(status: "ready")
    puts "[2] Import complete"

    # ======================================================================
    # SCENARIO A: Empty state (no site selected)
    # ======================================================================
    puts "\n#{"=" * 60}"
    puts "SCENARIO A: Empty state"
    puts "=" * 60

    a_errors = run_scenario(
      ds: ds, user: user, designs: designs,
      prompt: "Generate a page for the website when no site is selected. The title should be Ваши сайты and the subtitle is Выберите сайт чтобы продолжить",
      figma_node_id: "51215:5257",
      output_subdir: "scenario_a",
      checks: ->(jsx, page, errors) {
        # JSX structure
        check_jsx_fragments(jsx, errors, [
          "<Page>",
          "<SiteSelector",
          "Ваши сайты",
          "Выберите сайт чтобы продолжить",
          "</Page>"
        ])

        # No specific site should be selected
        select_match = jsx.to_s[/<Select[^\/]*\/>/]
        if select_match
          if select_match.include?("deadsimple")
            puts "  FAIL: Select should not have a specific site selected"
            errors << "Select should be empty in scenario A"
          else
            puts "  PASS: Select shows empty/default state"
          end
        end

        # Validation warnings
        check_validation_warnings(jsx, ds, errors)

        # DOM checks (if page available)
        if page
          check_plus_icon(page, errors)
          check_select_width(page, errors)
          check_select_background(page, errors)
          check_menu_item_icons(page, errors)
          check_search_menu_item(page, errors)
          check_footer_icons(page, errors)
          check_selected_item_z_index(page, errors)
        end
      }
    )
    all_errors.concat(a_errors.map { |e| "A: #{e}" })

    # ======================================================================
    # SCENARIO B: Selected state (site selected, active menu item)
    # ======================================================================
    puts "\n#{"=" * 60}"
    puts "SCENARIO B: Selected state"
    puts "=" * 60

    b_errors = run_scenario(
      ds: ds, user: user, designs: designs,
      prompt: "generate a website page. the active menu item is Сводка. the selected website is deadsimple.xyz. Page title - Сводка. subtitle - Информация о сайте",
      figma_node_id: "51215:5043",
      output_subdir: "scenario_b",
      checks: ->(jsx, page, errors) {
        # JSX structure
        check_jsx_fragments(jsx, errors, [
          "<Page>",
          "<SiteSelector",
          "deadsimple.xyz",
          "Сводка",
          "Информация о сайте",
          "</Page>"
        ])

        # Validation warnings
        check_validation_warnings(jsx, ds, errors)

        # SiteSelector Button is icon-only
        site_selector_jsx = jsx.to_s[/(<SiteSelector[\s\S]*?<\/SiteSelector>)/m, 1] || ""
        button_in_selector = site_selector_jsx[/<Button[^>]*>/]
        if button_in_selector && button_in_selector =~ /content="|text="/
          puts "  FAIL: Button in SiteSelector has text content"
          errors << "SiteSelector Button should be icon-only"
        else
          puts "  PASS: SiteSelector Button is icon-only"
        end

        # SiteMenu structure
        check_site_menu(jsx, errors)

        # DOM checks
        if page
          check_plus_icon(page, errors)
          check_plus_svg(page, errors)
          check_select_width(page, errors)
          check_menu_item_icons(page, errors)
          check_select_background(page, errors)
          check_search_menu_item(page, errors)
          check_footer_icons(page, errors)
          check_selected_item_z_index(page, errors)
        end
      }
    )
    all_errors.concat(b_errors.map { |e| "B: #{e}" })

    # ======================================================================
    # Final result
    # ======================================================================
    puts "\n#{"=" * 60}"
    puts "FINAL RESULT"
    puts "=" * 60
    puts "Output dir: #{OUTPUT_DIR}"
    if all_errors.empty?
      puts "ALL CHECKS PASSED"
    else
      puts "#{all_errors.size} FAILURES:"
      all_errors.each { |e| puts "  - #{e}" }
      exit 1
    end

  ensure
    if ds && ds.name.start_with?("E2E Webmaster")
      designs.each do |d|
        d.iterations.destroy_all
        d.chat_messages.destroy_all
        d.destroy
      end
      ds.figma_files.each { |ff| ff.component_sets.destroy_all; ff.components.destroy_all }
      ds.figma_files.destroy_all
      ds.destroy
      puts "\nCleaned up test DS ##{ds.id}"
    end
  end

  # ========================================================================
  # Scenario runner
  # ========================================================================
  def run_scenario(ds:, user:, designs:, prompt:, figma_node_id:, output_subdir:, checks:)
    output_dir = Rails.root.join("tmp", "e2e_webmaster", output_subdir)
    FileUtils.mkdir_p(output_dir)
    errors = []

    # Generate
    design = user.designs.create!(prompt: prompt, name: "E2E #{output_subdir}", design_system: ds, status: "generating")
    designs << design
    design.chat_messages.create!(author: "user", message: prompt)
    iteration = design.iterations.create!(comment: prompt)
    designer_msg = design.chat_messages.create!(author: "designer", message: "", state: "thinking")

    gen = DesignGenerator.new(design)
    task = gen.generate_task(prompt)
    puts "[AI] Calling OpenAI..."
    AiRequestJob.perform_now(task.id, iteration.id, designer_msg.id, :set_jsx)
    iteration.reload
    design.reload
    jsx = iteration.jsx

    puts "[AI] Done. Status: #{design.status}"
    puts "\n--- Generated JSX ---"
    puts jsx
    puts "---"

    # Fetch Figma reference
    figma_file_key = "oL5zKzFeTuZRd2rFMbUJWa"
    figma_path = Figma::VisualDiff.fetch_figma_screenshot(figma_file_key, figma_node_id, output_dir)

    # Render in Chrome
    react_path = nil
    browser_page = nil
    port = ENV.fetch("PORT", 3000)
    renderer_url = "http://127.0.0.1:#{port}/api/iterations/#{iteration.id}/renderer"

    chrome_path = ENV["BROWSER_PATH"] || ENV["GOOGLE_CHROME_BIN"] ||
      `which chromium 2>/dev/null`.strip.presence ||
      `which google-chrome 2>/dev/null`.strip.presence ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    browser = Ferrum::Browser.new(
      headless: true, browser_path: chrome_path, process_timeout: 30,
      browser_options: { "no-sandbox" => nil, "disable-setuid-sandbox" => nil },
      window_size: [1200, 800]
    )
    begin
      browser_page = browser.create_page
      browser_page.command("Emulation.setDeviceMetricsOverride", width: 1200, height: 800, deviceScaleFactor: 2, mobile: false)
      browser_page.goto(renderer_url)
      browser_page.network.wait_for_idle
      sleep 1

      browser_page.evaluate(<<~JS)
        window.postMessage({
          type: "render",
          jsx: `#{jsx.to_s.gsub('`', '\\\\`')}`,
        }, location.origin);
      JS
      sleep 2

      react_path = File.join(output_dir, "react.png")
      browser_page.screenshot(path: react_path, format: :png)

      # Run checks
      checks.call(jsx, browser_page, errors)
    ensure
      browser.quit
    end

    # Pixel diff
    if figma_path && react_path && File.exist?(figma_path) && File.exist?(react_path)
      diff_path = File.join(output_dir, "diff.png")
      diff_result = Figma::VisualDiff.new(nil, output_dir: output_dir).send(:pixel_diff, figma_path, react_path, diff_path)
      diff_pct = diff_result[:diff_percent].round(2)
      puts "  Diff: #{diff_result[:diff_pixels]}/#{diff_result[:total_pixels]} pixels (#{diff_pct}%)"

      generate_diff_analysis(figma_path, react_path, diff_path, output_dir)

      threshold_pct = 5.0
      if diff_pct < threshold_pct
        puts "  PASS: #{diff_pct}% diff < #{threshold_pct}% threshold"
      else
        puts "  FAIL: #{diff_pct}% diff >= #{threshold_pct}% threshold"
        errors << "Visual diff: #{diff_pct}%"
      end
    end

    errors
  end

  # ========================================================================
  # Reusable checks
  # ========================================================================
  def check_jsx_fragments(jsx, errors, fragments)
    puts "\n=== JSX structure ==="
    fragments.each do |fragment|
      if jsx.to_s.include?(fragment)
        puts "  PASS: #{fragment.inspect}"
      else
        puts "  FAIL: #{fragment.inspect}"
        errors << "JSX missing: #{fragment.inspect}"
      end
    end
  end

  def check_validation_warnings(jsx, ds, errors)
    puts "\n=== Validation warnings ==="
    used = jsx.to_s.scan(/<([A-Z]\w+)/).flatten.uniq
    warned = []
    ds.figma_files.where(version: ds.version).each do |ff|
      used.each do |name|
        record = ff.component_sets.detect { |c| c.name == name || c.name.tr(" ", "") == name } ||
                 ff.components.detect { |c| c.name == name || c.name.tr(" ", "") == name }
        next unless record
        w = record.validation_warnings || []
        warned << { name: name, warnings: w } if w.any?
      end
    end
    if warned.empty?
      puts "  PASS: All #{used.size} components valid"
    else
      warned.each { |w| w[:warnings].each { |msg| puts "  FAIL: #{w[:name]}: #{msg}" } }
      errors << "Validation warnings: #{warned.map { |w| w[:name] }.join(", ")}"
    end
  end

  def check_plus_icon(page, errors)
    puts "\n=== Plus icon ==="
    dom = page.evaluate("document.getElementById('root')?.innerHTML || ''").to_s.gsub(/\s+/, " ")
    has_plus = dom.include?('data-component="Plus"')
    has_white = dom.match?(/style="[^"]*color:\s*rgb\(255,\s*255,\s*255\)[^"]*"[^>]*>[^<]*<[^>]*data-component="Plus"/) ||
                dom.include?('style="color: rgb(255, 255, 255);')
    if has_plus && has_white
      puts "  PASS: White Plus icon found"
    else
      puts "  FAIL: #{has_plus ? "Plus found but missing white wrapper" : "No Plus icon"}"
      errors << "White Plus icon missing or wrong styles"
    end
  end

  def check_plus_svg(page, errors)
    puts "\n=== Plus SVG ==="
    html = page.evaluate("document.querySelector('[data-component=\"Plus\"]')?.innerHTML || ''")
    if html.to_s.include?("<svg")
      puts "  PASS: Plus contains inlined SVG"
    else
      puts "  FAIL: Plus missing SVG. innerHTML: #{html.to_s.first(200)}"
      errors << "Plus icon missing inlined SVG"
    end
  end

  def check_select_width(page, errors)
    puts "\n=== Select width ==="
    widths = page.evaluate(<<~JS)
      (() => {
        const slot = document.querySelector('[class*="siteselector"] [class*="website"], [class*="selector"] [class*="website"]');
        const select = slot && slot.querySelector('[data-component="Select"]');
        if (!slot || !select) return null;
        return { slot: slot.getBoundingClientRect().width, select: select.getBoundingClientRect().width };
      })()
    JS
    if widths.nil?
      puts "  SKIP: Could not find website slot or Select"
    elsif (widths["slot"] - widths["select"]).abs < 2
      puts "  PASS: Select width (#{widths["select"]}px) matches slot (#{widths["slot"]}px)"
    else
      puts "  FAIL: Select (#{widths["select"]}px) != slot (#{widths["slot"]}px)"
      errors << "Select width mismatch"
    end
  end

  def check_select_background(page, errors)
    puts "\n=== Select background ==="
    bg = page.evaluate(<<~JS)
      (() => {
        const el = document.querySelector('[data-component="Select"]');
        if (!el) return null;
        const inner = el.querySelector('div');
        return {
          rootBg: getComputedStyle(el).backgroundColor,
          innerBg: inner ? getComputedStyle(inner).backgroundColor : null
        };
      })()
    JS
    if bg.nil?
      puts "  SKIP: No Select in DOM"
    else
      root_ok = bg["rootBg"] == "rgba(0, 0, 0, 0)" || bg["rootBg"] == "transparent"
      inner_ok = bg["innerBg"] && bg["innerBg"] != "rgba(0, 0, 0, 0)" && bg["innerBg"] != "transparent"
      if root_ok && inner_ok
        puts "  PASS: Background on inner (#{bg["innerBg"]}), root transparent"
      else
        puts "  FAIL: root=#{bg["rootBg"]}, inner=#{bg["innerBg"]}"
        errors << "Select background wrong"
      end
    end
  end

  def check_site_menu(jsx, errors)
    puts "\n=== SiteMenu structure ==="
    menu_jsx = jsx.to_s[/<SiteMenu>[\s\S]*?<\/SiteMenu>/m] || ""
    items = menu_jsx.scan(/<SiteMenuItem\s+([^\/]*)\/>/).map do |match|
      props = {}
      match[0].scan(/(\w+)=(?:"([^"]*)"|(\{[^}]*\}))/).each { |k, s, e| props[k] = s || e }
      props
    end

    menu_errors = []
    menu_errors << "Expected >= 10 SiteMenuItems, got #{items.size}" if items.size < 10

    svodka = items.find { |p| p["title"] == "Сводка" }
    if svodka
      menu_errors << "Сводка should be selected" unless svodka["selected"] == "{true}"
      menu_errors << "Сводка should NOT have hasChildren" if svodka["hasChildren"]
    else
      menu_errors << "Missing SiteMenuItem title=\"Сводка\""
    end

    others = items.reject { |p| p["title"] == "Сводка" }
    missing = others.reject { |p| p["hasChildren"] == "{true}" }
    menu_errors << "#{missing.size} items missing hasChildren: #{missing.map { |p| p["title"] }.join(", ")}" if missing.any?

    if menu_errors.empty?
      puts "  PASS: #{items.size} items, Сводка selected, others have hasChildren"
    else
      menu_errors.each { |e| puts "  FAIL: #{e}" }
      errors << "SiteMenu: #{menu_errors.join("; ")}"
    end
  end

  # The SiteMenu has a fixed first item "Поиск" with Magnifier icon.
  # It's rendered by the SiteMenu component code, not from AI JSX.
  def check_search_menu_item(page, errors)
    puts "\n=== Search menu item (Поиск) ==="
    result = page.evaluate(<<~JS)
      (() => {
        const menu = document.querySelector('[data-component="SiteMenu"]');
        if (!menu) return null;
        // The fixed first SiteMenuItem is rendered by SiteMenu, before the slot
        const items = menu.querySelectorAll('[data-component="SiteMenuItem"]');
        if (!items.length) return { found: false };
        const first = items[0];
        const text = first.textContent || '';
        const hasSvg = !!first.querySelector('svg');
        return { found: true, text: text.trim(), hasSvg: hasSvg };
      })()
    JS
    if result.nil? || !result["found"]
      puts "  SKIP: No SiteMenu or SiteMenuItems in DOM"
    elsif result["text"].include?("Поиск") || result["text"].include?("Название пункта")
      # "Название пункта" is the default text — the SiteMenu should override it to "Поиск"
      if result["text"].include?("Поиск")
        puts "  PASS: First menu item is \"Поиск\""
      else
        puts "  FAIL: First menu item shows default text \"#{result["text"].first(50)}\" instead of \"Поиск\""
        errors << "Search menu item shows default text, not \"Поиск\""
      end
    else
      puts "  FAIL: First menu item text is \"#{result["text"].first(50)}\", expected \"Поиск\""
      errors << "Search menu item text wrong"
    end
  end

  # The footer should render visible icons (person, bell, question, gear), not a black square
  def check_footer_icons(page, errors)
    puts "\n=== Footer icons ==="
    result = page.evaluate(<<~JS)
      (() => {
        const footer = document.querySelector('[data-component="MenuFooter"]');
        if (!footer) return null;
        const svgs = footer.querySelectorAll('svg');
        const bbox = footer.getBoundingClientRect();
        const bg = getComputedStyle(footer).backgroundColor;
        return {
          svgCount: svgs.length,
          width: bbox.width,
          height: bbox.height,
          bg: bg
        };
      })()
    JS
    if result.nil?
      puts "  SKIP: No MenuFooter in DOM"
    elsif result["svgCount"] >= 3
      puts "  PASS: Footer has #{result["svgCount"]} SVG icons"
    else
      puts "  FAIL: Footer has #{result["svgCount"]} SVG icons (expected >= 3), bg=#{result["bg"]}"
      errors << "Footer missing icons (#{result["svgCount"]} SVGs, expected >= 3)"
    end
  end

  # The selected menu item's background should be behind the text, not covering it
  def check_selected_item_z_index(page, errors)
    puts "\n=== Selected item z-index ==="
    result = page.evaluate(<<~JS)
      (() => {
        const items = document.querySelectorAll('[data-component="SiteMenuItem"]');
        for (const item of items) {
          const bg = item.querySelector('[class*="background"]');
          if (!bg || getComputedStyle(bg).display === 'none') continue;
          // Found the selected item with visible background
          const bgZ = parseInt(getComputedStyle(bg).zIndex) || 0;
          const bgPos = getComputedStyle(bg).position;
          const text = item.querySelector('span');
          const textZ = text ? (parseInt(getComputedStyle(text).zIndex) || 0) : 0;
          // Background should be behind text: either lower z-index or positioned behind
          return {
            found: true,
            bgZ: bgZ,
            bgPos: bgPos,
            textZ: textZ,
            bgCoversText: bgPos === 'absolute' && bgZ >= textZ && textZ === 0
          };
        }
        return { found: false };
      })()
    JS
    if result.nil? || !result["found"]
      puts "  SKIP: No selected item with background found"
    elsif result["bgCoversText"]
      puts "  FAIL: Selected background covers text (bg z-index=#{result["bgZ"]}, position=#{result["bgPos"]}, text z-index=#{result["textZ"]})"
      errors << "Selected item background covers text (z-index issue)"
    else
      puts "  PASS: Selected background is behind text"
    end
  end

  def check_menu_item_icons(page, errors)
    puts "\n=== Menu item icons ==="
    result = page.evaluate(<<~JS)
      (() => {
        const items = document.querySelectorAll('[data-component="SiteMenuItem"]');
        return Array.from(items).map((el, i) => {
          const svg = el.querySelector('svg');
          const icon = el.querySelector('[data-component]');
          const iconName = icon ? icon.getAttribute('data-component') : null;
          return { index: i, hasSvg: !!svg, iconName: iconName };
        });
      })()
    JS

    if result.nil? || result.empty?
      puts "  SKIP: No SiteMenuItems in DOM"
      return
    end

    missing_svg = result.select { |r| !r["hasSvg"] }
    if missing_svg.empty?
      puts "  PASS: All #{result.size} menu items have SVG icons"
    else
      puts "  FAIL: #{missing_svg.size}/#{result.size} menu items missing SVG icon"
      missing_svg.each { |r| puts "    item #{r["index"]}: icon=#{r["iconName"] || "none"}" }
      errors << "#{missing_svg.size} menu items missing SVG icons"
    end
  end

  # ========================================================================
  # Diff analysis
  # ========================================================================
  def generate_diff_analysis(figma_path, react_path, diff_path, output_dir)
    require "chunky_png"

    diff = ChunkyPNG::Image.from_file(diff_path)
    react = ChunkyPNG::Image.from_file(react_path)
    figma = ChunkyPNG::Image.from_file(figma_path)

    w = [diff.width, react.width, figma.width].min
    h = [diff.height, react.height, figma.height].min

    grid_cols, grid_rows = 6, 8
    cell_w, cell_h = w / grid_cols, h / grid_rows

    regions = []
    grid_rows.times do |row|
      grid_cols.times do |col|
        x0, y0 = col * cell_w, row * cell_h
        count = 0
        cell_h.times do |dy|
          cell_w.times do |dx|
            px = diff[x0 + dx, y0 + dy]
            count += 1 if ChunkyPNG::Color.r(px) > 100 && ChunkyPNG::Color.a(px) > 0
          end
        end
        pct = (count * 100.0 / (cell_w * cell_h)).round(1)
        regions << { x: x0, y: y0, pct: pct, count: count } if pct > 0.5
      end
    end

    if regions.any?
      puts "  Problem regions (>0.5% diff):"
      regions.sort_by { |r| -r[:pct] }.first(5).each do |r|
        puts "    (#{r[:x]},#{r[:y]})–(#{r[:x] + cell_w},#{r[:y] + cell_h}): #{r[:pct]}% (#{r[:count]} px)"
      end
    end

    comparison = ChunkyPNG::Image.new(w * 3, h, ChunkyPNG::Color::WHITE)
    h.times do |y|
      w.times do |x|
        comparison[x, y] = figma[x, y]
        comparison[x + w, y] = react[x, y]
        comparison[x + w * 2, y] = diff[x, y]
      end
    end
    comp_path = File.join(output_dir, "comparison.png")
    comparison.save(comp_path)
    puts "  Comparison: #{comp_path}"

    diff_pct = regions.any? ? (regions.sum { |r| r[:count] } * 100.0 / (w * h)).round(2) : 0
    ai_inspect_diff(comp_path, diff_pct: diff_pct)
  rescue => e
    puts "  Warning: diff analysis failed: #{e.message}"
  end

  def ai_inspect_diff(comparison_path, diff_pct: 0)
    return if diff_pct < 0.1

    image_data = Base64.strict_encode64(File.binread(comparison_path))
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

    payload = {
      model: "gpt-4o",
      input: [{
        role: "user",
        content: [
          { type: "input_text", text: "This is a side-by-side comparison: LEFT = Figma design (reference), MIDDLE = React render (our code), RIGHT = pixel diff (red = different).\n\nList every visual difference between LEFT and MIDDLE. Be specific: name the element, describe what's wrong. One line per issue. Ignore anti-aliasing." },
          { type: "input_image", image_url: "data:image/png;base64,#{image_data}" }
        ]
      }],
      max_output_tokens: 1000
    }

    raw = HTTP.auth("Bearer #{ENV.fetch('OPENAI_API_KEY')}").post("https://api.openai.com/v1/responses", json: payload, ssl_context: ctx).body.to_s
    parsed = JSON.parse(raw)
    text = parsed.dig("output", 0, "content", 0, "text") || parsed.dig("choices", 0, "message", "content")

    if text
      puts "\n  === AI Visual Inspection ==="
      text.strip.lines.each { |l| puts "  #{l.rstrip}" }
    end
  rescue => e
    puts "  Warning: AI inspection failed: #{e.message}"
  end
end
