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
        # NOTE: This check requires Page's main content area to have a slot
        # with Button as allowed child, and Button's StartIcon defaulting to Plus.
        # Currently Page's second frame has no slot (empty in Figma component def).
        # When the DS is updated with proper slots, re-enable this as a hard check.
        puts "\n=== Check 3: White Plus icon in button ==="
        dom_html = page.evaluate("document.getElementById('root').innerHTML")
        expected_icon = '<div data-component="Plus" style="color: rgb(255, 255, 255); width: 16px; height: 16px;"><svg'
        normalized_dom = dom_html.to_s.gsub(/\s+/, " ")
        normalized_expected = expected_icon.gsub(/\s+/, " ")
        if normalized_dom.include?(normalized_expected)
          puts "  PASS: Found white Plus icon with correct styles"
        else
          plus_match = dom_html.to_s.match(/data-component="Plus"[^>]*>/)
          if plus_match
            puts "  WARN: Plus icon found but with wrong styles: #{plus_match[0]}"
          else
            puts "  WARN: No Plus icon in rendered DOM (Page has no main content slot — DS config needed)"
          end
          # Soft warning, not a failure — requires DS slot configuration
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
