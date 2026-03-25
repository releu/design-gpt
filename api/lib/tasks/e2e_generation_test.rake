require "fileutils"
$stdout.sync = true

namespace :e2e do
  desc "Webmaster DS: import, generate, assert JSX, visual diff against Figma"
  task webmaster: :environment do
    OUTPUT_DIR = Rails.root.join("tmp", "e2e_webmaster")
    FileUtils.mkdir_p(OUTPUT_DIR)

    source_ds = DesignSystem.find(1)
    user = source_ds.user || User.first
    errors = []
    ds = nil
    design = nil

    puts "=== E2E Webmaster Test ==="

    # --- Step 1: Create fresh DS and import (parallel) ---
    ds = DesignSystem.create!(name: "E2E Webmaster #{Time.now.to_i}", user: user)
    puts "[1/4] Created DS ##{ds.id}"

    # Create all FigmaFile records first (main thread)
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

    # Import all files in parallel threads
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
    puts "[2/4] Import complete"

    # --- Step 2: Generate with AI ---
    prompt = "Generate a page layout for website deadsimple.xyz"
    design = user.designs.create!(
      prompt: prompt,
      name: "E2E Webmaster Design",
      design_system: ds,
      status: "generating"
    )
    design.chat_messages.create!(author: "user", message: prompt)
    iteration = design.iterations.create!(comment: prompt)
    designer_msg = design.chat_messages.create!(author: "designer", message: "", state: "thinking")

    gen = DesignGenerator.new(design)
    task = gen.generate_task(prompt)
    puts "[3/4] Calling OpenAI..."

    AiRequestJob.perform_now(task.id, iteration.id, designer_msg.id, :set_jsx)
    iteration.reload
    design.reload
    jsx = iteration.jsx

    puts "[4/4] Generation done. Status: #{design.status}"
    puts "\n--- Generated JSX ---"
    puts jsx
    puts "---"

    # ========================================
    # CHECK 1: JSX structure
    # ========================================
    puts "\n=== Check 1: JSX structure ==="
    [
      "<Page>",
      '<Slot name="sideColumnItems">',
      "<SiteSelector",
      "<Select",
      "deadsimple.xyz",
      "</Page>"
    ].each do |fragment|
      if jsx.to_s.include?(fragment)
        puts "  PASS: #{fragment.inspect}"
      else
        puts "  FAIL: #{fragment.inspect}"
        errors << "JSX missing: #{fragment.inspect}"
      end
    end

    # ========================================
    # CHECK 1b: All used components are valid (no warnings)
    # ========================================
    puts "\n=== Check 1b: Component validation warnings ==="
    # Extract component names from JSX tags
    used_components = jsx.to_s.scan(/<([A-Z]\w+)/).flatten.uniq
    warned_components = []

    ds.figma_files.where(version: ds.version).each do |ff|
      used_components.each do |comp_name|
        cs = ff.component_sets.detect { |c| c.name == comp_name || c.name.tr(" ", "") == comp_name }
        c = ff.components.detect { |c| c.name == comp_name || c.name.tr(" ", "") == comp_name } unless cs
        record = cs || c
        next unless record

        warnings = record.validation_warnings || []
        if warnings.any?
          warned_components << { name: comp_name, warnings: warnings }
        end
      end
    end

    if warned_components.empty?
      puts "  PASS: All #{used_components.size} components (#{used_components.join(", ")}) have no warnings"
    else
      warned_components.each do |wc|
        wc[:warnings].each { |w| puts "  FAIL: #{wc[:name]}: #{w}" }
      end
      errors << "#{warned_components.size} component(s) have validation warnings: #{warned_components.map { |w| w[:name] }.join(", ")}"
    end

    # ========================================
    # CHECK 2: Main page visual diff vs Figma
    # ========================================
    puts "\n=== Check 2: Main page diff ==="
    figma_file_key = "oL5zKzFeTuZRd2rFMbUJWa"
    figma_node_id = "51108:11396"

    # Fetch Figma reference screenshot
    figma_path = Figma::VisualDiff.fetch_figma_screenshot(figma_file_key, figma_node_id, OUTPUT_DIR)
    if figma_path
      puts "  Figma screenshot: #{figma_path}"
    else
      puts "  FAIL: Could not fetch Figma screenshot"
      errors << "Figma screenshot fetch failed"
    end

    # Render the generated design in headless Chrome
    react_path = nil
    if jsx.present? && figma_path
      port = ENV.fetch("PORT", 3000)
      renderer_url = "http://127.0.0.1:#{port}/api/iterations/#{iteration.id}/renderer"

      chrome_path = ENV["BROWSER_PATH"] || ENV["GOOGLE_CHROME_BIN"] ||
        `which chromium 2>/dev/null`.strip.presence ||
        `which google-chrome 2>/dev/null`.strip.presence ||
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      browser = Ferrum::Browser.new(
        headless: true,
        browser_path: chrome_path,
        process_timeout: 30,
        browser_options: { "no-sandbox" => nil, "disable-setuid-sandbox" => nil },
        window_size: [393, 800]
      )
      begin
        page = browser.create_page
        page.command("Emulation.setDeviceMetricsOverride", width: 393, height: 800, deviceScaleFactor: 1, mobile: true)
        page.goto(renderer_url)
        page.network.wait_for_idle
        sleep 1

        page.evaluate(<<~JS)
          window.postMessage({
            type: "render",
            jsx: `#{jsx.gsub('`', '\\\\`')}`,
          }, location.origin);
        JS
        sleep 2

        react_path = File.join(OUTPUT_DIR, "react.png")
        page.screenshot(path: react_path, full: true, format: :png)
        puts "  React screenshot: #{react_path}"

        # ========================================
        # CHECK 3: White Plus icon in rendered DOM
        # ========================================
        # SiteSelector renders <Button StartIconComponent={Plus} />.
        # The Button variant (view=Action, iconOnly=On) wraps the icon
        # in a styled span with color/size overrides. SVG icons inherit
        # the color via CSS currentColor.
        puts "\n=== Check 3: White Plus icon in button ==="
        dom_html = page.evaluate("document.getElementById('root')?.innerHTML || ''")
        normalized_dom = dom_html.to_s.gsub(/\s+/, " ")
        has_plus = normalized_dom.include?('data-component="Plus"')
        has_white_wrapper = normalized_dom.match?(/style="[^"]*color:\s*rgb\(255,\s*255,\s*255\)[^"]*"[^>]*>[^<]*<[^>]*data-component="Plus"/) ||
                            normalized_dom.include?('style="color: rgb(255, 255, 255);')
        if has_plus && has_white_wrapper
          puts "  PASS: Found white Plus icon with correct styles"
        else
          if !has_plus
            puts "  FAIL: No Plus icon found in rendered DOM"
          else
            # Show context around Plus icon
            plus_ctx = dom_html.to_s.match(/.{0,100}data-component="Plus".{0,100}/)
            puts "  FAIL: Plus icon found but missing white color wrapper"
            puts "  Context: #{plus_ctx&.[](0)&.first(250)}" if plus_ctx
          end
          errors << "White Plus icon missing or wrong styles"
        end

        # ========================================
        # CHECK 4: Plus icon contains inlined SVG
        # ========================================
        # The Plus component should render an actual <svg> element via
        # dangerouslySetInnerHTML, not an <img> tag or empty placeholder.
        puts "\n=== Check 4: Plus icon contains inlined SVG ==="
        plus_html = page.evaluate(<<~JS)
          (() => {
            const el = document.querySelector('[data-component="Plus"]');
            return el ? el.innerHTML : '';
          })()
        JS
        if plus_html.to_s.include?("<svg")
          puts "  PASS: Plus icon contains inlined <svg> element"
        else
          puts "  FAIL: Plus icon does not contain inlined <svg> element"
          puts "  innerHTML: #{plus_html.to_s.first(300)}"
          errors << "Plus icon missing inlined SVG"
        end

        # ========================================
        # CHECK 5: Select fills the website slot width
        # ========================================
        # The Select inside the "website" slot should stretch to match
        # the slot container's width (not be narrower).
        puts "\n=== Check 5: Select fills website slot width ==="
        widths = page.evaluate(<<~JS)
          (() => {
            const slot = document.querySelector('[class*="website"]');
            const select = slot && slot.querySelector('[data-component="Select"]');
            if (!slot || !select) return null;
            return {
              slot: slot.getBoundingClientRect().width,
              select: select.getBoundingClientRect().width
            };
          })()
        JS
        if widths.nil?
          puts "  FAIL: Could not find website slot or Select component"
          errors << "Select width check: elements not found"
        elsif (widths["slot"] - widths["select"]).abs < 2
          puts "  PASS: Select width (#{widths["select"]}px) matches slot (#{widths["slot"]}px)"
        else
          puts "  FAIL: Select width (#{widths["select"]}px) != slot width (#{widths["slot"]}px)"
          errors << "Select width mismatch: select=#{widths["select"]}px slot=#{widths["slot"]}px"
        end

        # ========================================
        # CHECK 6: Select background on inner element
        # ========================================
        # The background should be on .selectv0-select-1 (the inner frame),
        # not on .selectv0-root (the component root div).
        puts "\n=== Check 6: Select background on inner element ==="
        bg_info = page.evaluate(<<~JS)
          (() => {
            const selectEl = document.querySelector('[data-component="Select"]');
            if (!selectEl) return null;
            // root is the data-component element itself; inner is its first child div
            const inner = selectEl.querySelector('div');
            const rootBg = getComputedStyle(selectEl).backgroundColor;
            const innerBg = inner ? getComputedStyle(inner).backgroundColor : null;
            return {
              rootBg, innerBg,
              rootClass: selectEl.className,
              innerClass: inner ? inner.className : null
            };
          })()
        JS
        if bg_info.nil?
          puts "  FAIL: Could not find Select component in DOM"
          errors << "Select background check: elements not found"
        else
          root_transparent = bg_info["rootBg"] == "rgba(0, 0, 0, 0)" || bg_info["rootBg"] == "transparent"
          inner_has_bg = bg_info["innerBg"] && bg_info["innerBg"] != "rgba(0, 0, 0, 0)" && bg_info["innerBg"] != "transparent"
          if root_transparent && inner_has_bg
            puts "  PASS: Background on inner (#{bg_info["innerBg"]}), root is transparent"
          else
            puts "  FAIL: root bg=#{bg_info["rootBg"]} (#{bg_info["rootClass"]}), inner bg=#{bg_info["innerBg"]} (#{bg_info["innerClass"]})"
            errors << "Select background wrong: root=#{bg_info["rootBg"]} inner=#{bg_info["innerBg"]}"
          end
        end

      ensure
        browser.quit
      end
    end

    # Pixel diff
    if figma_path && react_path && File.exist?(figma_path) && File.exist?(react_path)
      diff_path = File.join(OUTPUT_DIR, "diff.png")
      diff_result = Figma::VisualDiff.new(nil, output_dir: OUTPUT_DIR).send(:pixel_diff, figma_path, react_path, diff_path)

      diff_px = diff_result[:diff_pixels]
      total_px = diff_result[:total_pixels]
      diff_pct = diff_result[:diff_percent].round(2)

      puts "  Diff: #{diff_px}/#{total_px} pixels (#{diff_pct}%)"
      puts "  Diff image: #{diff_path}"

      # The side column (SiteSelector with Select) should match closely.
      # The main content area is empty (no slot in Page) so expect some diff.
      # Threshold: 5% of total pixels — catches major rendering breaks.
      threshold_pct = 5.0
      if diff_pct < threshold_pct
        puts "  PASS: #{diff_pct}% diff < #{threshold_pct}% threshold"
      else
        puts "  FAIL: #{diff_pct}% diff >= #{threshold_pct}% threshold"
        errors << "Visual diff: #{diff_pct}% (threshold: #{threshold_pct}%)"
      end
    elsif !figma_path
      # already recorded above
    else
      puts "  FAIL: Could not produce React screenshot"
      errors << "React screenshot failed"
    end

    # ========================================
    # Result
    # ========================================
    puts "\n=== Result ==="
    puts "Output dir: #{OUTPUT_DIR}"
    if errors.empty?
      puts "ALL CHECKS PASSED"
    else
      puts "#{errors.size} FAILURES:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end

  ensure
    if ds && ds.name.start_with?("E2E Webmaster")
      design&.iterations&.destroy_all
      design&.chat_messages&.destroy_all
      design&.destroy
      ds.figma_files.each { |ff| ff.component_sets.destroy_all; ff.components.destroy_all }
      ds.figma_files.destroy_all
      ds.destroy
      puts "\nCleaned up test DS ##{ds.id}"
    end
  end
end
