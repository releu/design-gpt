require "fileutils"
require "json"
$stdout.sync = true

# ==========================================================================
# Figma-to-React Pipeline Test Suite
#
# Tests the complete pipeline: Import → Asset Extraction → Code Generation → Rendering
# Compares rendered React components against Figma screenshots pixel-by-pixel.
#
# Usage:
#   rake pipeline:test              # Full suite against live Figma API
#   rake pipeline:test_cached       # Use cached Figma screenshots (no API calls for screenshots)
#   rake pipeline:freeze            # Save current Figma screenshots as frozen fixtures
#
# Output:
#   tmp/pipeline_test/report.json   # Machine-readable results
#   tmp/pipeline_test/diffs/        # Diff images for visual inspection
# ==========================================================================

namespace :pipeline do
  OUTPUT_DIR = Rails.root.join("tmp", "pipeline_test")
  FIXTURES_DIR = Rails.root.join("spec", "fixtures", "figma_screenshots")
  DIFF_DIR = OUTPUT_DIR.join("diffs")
  REPORT_PATH = OUTPUT_DIR.join("report.json")

  desc "Run full pipeline test suite"
  task test: :environment do
    run_pipeline_test(use_frozen: false)
  end

  desc "Run pipeline test using frozen Figma screenshots (no API calls for screenshots)"
  task test_cached: :environment do
    run_pipeline_test(use_frozen: true)
  end

  desc "Structural diff: hide text/shadows, compare layout only"
  task structural: :environment do
    run_structural_test
  end

  desc "Freeze current Figma screenshots as test fixtures"
  task freeze: :environment do
    freeze_figma_screenshots
  end

  # ==========================================================================
  # Main Test Runner
  # ==========================================================================

  def run_pipeline_test(use_frozen: false)
    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(DIFF_DIR)

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    report = { timestamp: Time.now.iso8601, layers: {}, components: [], summary: {} }

    ds = DesignSystem.find_by(name: "WM") || DesignSystem.first
    abort "No design system found" unless ds

    ff_main = ds.current_figma_files.find_by(figma_file_key: "oL5zKzFeTuZRd2rFMbUJWa")
    abort "WM FigmaFile not found" unless ff_main

    puts "=" * 70
    puts "PIPELINE TEST SUITE"
    puts "=" * 70
    puts "Design System: #{ds.name} (v#{ds.version})"
    puts "FigmaFiles: #{ds.current_figma_files.count}"
    puts ""

    # ------------------------------------------------------------------
    # Layer 1: Import Integrity
    # ------------------------------------------------------------------
    puts "=" * 70
    puts "LAYER 1: IMPORT INTEGRITY"
    puts "=" * 70

    layer1 = run_layer1(ff_main)
    report[:layers][:import] = layer1
    puts "  #{layer1[:status] == 'pass' ? '✓' : '✗'} #{layer1[:checks_passed]}/#{layer1[:checks_total]} checks passed"
    layer1[:failures].each { |f| puts "    FAIL: #{f}" } if layer1[:failures]&.any?
    puts ""

    # ------------------------------------------------------------------
    # Layer 2: Codegen Structural Checks
    # ------------------------------------------------------------------
    puts "=" * 70
    puts "LAYER 2: CODEGEN STRUCTURAL CHECKS"
    puts "=" * 70

    layer2 = run_layer2(ff_main)
    report[:layers][:codegen] = layer2
    puts "  #{layer2[:status] == 'pass' ? '✓' : '✗'} #{layer2[:checks_passed]}/#{layer2[:checks_total]} checks passed"
    layer2[:failures].each { |f| puts "    FAIL: #{f}" } if layer2[:failures]&.any?
    puts ""

    # ------------------------------------------------------------------
    # Layer 3: Render Integrity
    # ------------------------------------------------------------------
    puts "=" * 70
    puts "LAYER 3: RENDER INTEGRITY"
    puts "=" * 70

    layer3 = run_layer3(ds)
    report[:layers][:render] = layer3
    puts "  #{layer3[:status] == 'pass' ? '✓' : '✗'} #{layer3[:rendered]}/#{layer3[:total]} components render without errors"
    layer3[:failures].each { |f| puts "    FAIL: #{f}" } if layer3[:failures]&.any?
    puts ""

    # ------------------------------------------------------------------
    # Layer 4: Visual Fidelity
    # ------------------------------------------------------------------
    puts "=" * 70
    puts "LAYER 4: VISUAL FIDELITY"
    puts "=" * 70

    layer4 = run_layer4(ds, ff_main, use_frozen: use_frozen)
    report[:layers][:visual] = layer4[:summary]
    report[:components] = layer4[:components]

    puts "  Pass (< 100px diff): #{layer4[:summary][:pass]}/#{layer4[:summary][:total]}"
    puts "  Fail (>= 100px diff): #{layer4[:summary][:fail]}/#{layer4[:summary][:total]}"
    puts "  Average diff: #{layer4[:summary][:avg_diff]} px"
    puts ""

    # Show worst offenders
    worst = layer4[:components].sort_by { |c| -(c[:diff_pixels] || 0) }.first(10)
    worst.each do |c|
      status = (c[:diff_pixels] || 0) < 100 ? "PASS" : "FAIL"
      puts "  [#{status}] #{c[:diff_pixels] || '?'}px - #{c[:name]}"
    end
    puts ""

    # ------------------------------------------------------------------
    # Performance
    # ------------------------------------------------------------------
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(1)
    report[:summary] = {
      total_time_s: elapsed,
      layer1: layer1[:status],
      layer2: layer2[:status],
      layer3: layer3[:status],
      layer4_pass_rate: layer4[:summary][:total] > 0 ? (layer4[:summary][:pass].to_f / layer4[:summary][:total] * 100).round(1) : 0
    }

    File.write(REPORT_PATH, JSON.pretty_generate(report))

    puts "=" * 70
    puts "SUMMARY"
    puts "=" * 70
    puts "  Layer 1 (Import):   #{layer1[:status].upcase}"
    puts "  Layer 2 (Codegen):  #{layer2[:status].upcase}"
    puts "  Layer 3 (Render):   #{layer3[:status].upcase}"
    puts "  Layer 4 (Visual):   #{layer4[:summary][:pass]}/#{layer4[:summary][:total]} pass"
    puts "  Time: #{elapsed}s"
    puts "  Report: #{REPORT_PATH}"
    puts "=" * 70

    # Exit with failure if any layer fails
    exit(1) if layer1[:status] == "fail" || layer2[:status] == "fail" || layer3[:status] == "fail"
  end

  # ==========================================================================
  # Layer 1: Import Integrity
  # ==========================================================================

  def run_layer1(ff)
    expected_path = Rails.root.join("spec", "fixtures", "figma", "wm_expected.json")
    unless File.exist?(expected_path)
      return { status: "skip", message: "No fixture at #{expected_path}. Run pipeline:freeze first." }
    end

    expected = JSON.parse(File.read(expected_path))
    checks_passed = 0
    checks_total = 0
    failures = []

    # Check totals
    [
      ["component_sets", ff.component_sets.count, expected["totals"]["component_sets"]],
      ["components", ff.components.count, expected["totals"]["components"]],
    ].each do |name, actual, exp|
      checks_total += 1
      if actual == exp
        checks_passed += 1
      else
        failures << "#{name}: expected #{exp}, got #{actual}"
      end
    end

    # Check each component set (keyed by node_id)
    expected["component_sets"].each do |node_id, exp|
      cs = ff.component_sets.find_by(node_id: node_id)
      checks_total += 1
      unless cs
        failures << "component_set '#{exp['name']}' (#{node_id}) not found"
        next
      end
      checks_passed += 1

      label = exp["name"]

      # Check props
      actual_prop_keys = (cs.prop_definitions || {}).keys.sort
      checks_total += 1
      if actual_prop_keys == exp["prop_keys"]
        checks_passed += 1
      else
        failures << "#{label} prop_keys: expected #{exp['prop_keys'].size}, got #{actual_prop_keys.size}"
      end

      # Check slots
      checks_total += 1
      actual_slots = (cs.slots || []).map { |s| s["name"] }
      if actual_slots == exp["slot_names"]
        checks_passed += 1
      else
        failures << "#{label} slots: expected #{exp['slot_names']}, got #{actual_slots}"
      end

      # Check variant count
      checks_total += 1
      if cs.variants.count == exp["variant_count"]
        checks_passed += 1
      else
        failures << "#{label} variants: expected #{exp['variant_count']}, got #{cs.variants.count}"
      end

      # Check has code
      checks_total += 1
      has_code = cs.variants.any? { |v| v.react_code_compiled.present? }
      if has_code == exp["has_code"]
        checks_passed += 1
      else
        failures << "#{label} has_code: expected #{exp['has_code']}, got #{has_code}"
      end
    end

    # Check standalone components (keyed by node_id)
    expected["components"].each do |node_id, exp|
      comp = ff.components.find_by(node_id: node_id)
      checks_total += 1
      unless comp
        failures << "component '#{exp['name']}' (#{node_id}) not found"
        next
      end
      checks_passed += 1

      checks_total += 1
      if comp.react_code_compiled.present? == exp["has_code"]
        checks_passed += 1
      else
        failures << "#{exp['name']} has_code: expected #{exp['has_code']}, got #{comp.react_code_compiled.present?}"
      end
    end

    {
      status: failures.empty? ? "pass" : "fail",
      checks_passed: checks_passed,
      checks_total: checks_total,
      failures: failures
    }
  end

  # ==========================================================================
  # Layer 2: Codegen Structural Checks
  # ==========================================================================

  def run_layer2(ff)
    checks_passed = 0
    checks_total = 0
    failures = []

    all_sets = ff.component_sets.includes(:variants).to_a
    all_comps = ff.components.to_a

    (all_sets + all_comps).each do |record|
      name = record.name
      is_set = record.is_a?(ComponentSet)

      # Get compiled code
      compiled = if is_set
        record.variants.map(&:react_code_compiled).compact.first
      else
        record.react_code_compiled
      end

      # Check: has compiled code
      checks_total += 1
      if compiled.present?
        checks_passed += 1
      else
        failures << "#{name}: no compiled code"
        next
      end

      # Check: has data-component attribute
      checks_total += 1
      if compiled.include?("data-component")
        checks_passed += 1
      else
        failures << "#{name}: missing data-component attribute"
      end

      # Check: no pink placeholder when no warnings
      warnings = record.validation_warnings || []
      if warnings.empty?
        checks_total += 1
        if !compiled.include?("#FF69B4") && !compiled.include?("FF69B4")
          checks_passed += 1
        else
          failures << "#{name}: has pink placeholder but no validation_warnings"
        end
      end
    end

    {
      status: failures.empty? ? "pass" : "fail",
      checks_passed: checks_passed,
      checks_total: checks_total,
      failures: failures
    }
  end

  # ==========================================================================
  # Layer 3: Render Integrity (needs Node.js + Playwright)
  # ==========================================================================

  def run_layer3(ds)
    # Write a Node.js script that renders each component and checks for errors
    script = <<~JS
      const { chromium } = require('playwright');
      (async () => {
        const browser = await chromium.launch();
        const page = await browser.newPage({ viewport: { width: 800, height: 600 }, ignoreHTTPSErrors: true });

        const errors = {};
        page.on('pageerror', err => {
          errors[err.message.split('\\n')[0]] = (errors[err.message.split('\\n')[0]] || 0) + 1;
        });

        await page.goto('https://design-gpt.localtest.me/api/design-systems/#{ds.id}/renderer', { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);

        // Collect all registered component names
        const componentNames = await page.evaluate(() => {
          const names = [];
          const skip = new Set(['React', 'ReactDOM', 'Babel', 'Slot']);
          document.querySelectorAll('script').forEach(s => {
            const match = s.textContent.match(/var\\s+([A-Z][a-zA-Z0-9_]+)\\s*=/g);
            if (match) {
              match.forEach(m => {
                const name = m.replace(/^var\\s+/, '').replace(/\\s*=$/, '');
                if (!skip.has(name) && /^[A-Z]/.test(name)) names.push(name);
              });
            }
          });
          return [...new Set(names)];
        });

        const results = [];
        for (const name of componentNames) {
          const result = await page.evaluate((name) => {
            const root = document.getElementById('root');
            root.innerHTML = '';
            try {
              if (typeof window[name] !== 'function') return { name, status: 'not_function' };
              ReactDOM.render(React.createElement(window[name]), root);
              const el = root.querySelector('[data-component]');
              if (!el) return { name, status: 'no_element' };
              const rect = el.getBoundingClientRect();
              return { name, status: 'ok', w: Math.round(rect.width), h: Math.round(rect.height) };
            } catch(e) {
              return { name, status: 'error', error: e.message.substring(0, 100) };
            }
          }, name);
          results.push(result);
        }

        const errorCount = Object.keys(errors).length;
        console.log(JSON.stringify({ results, scriptErrors: errorCount, errorSample: Object.keys(errors).slice(0, 5) }));
        await browser.close();
      })();
    JS

    script_path = OUTPUT_DIR.join("render_test.js")
    qa_dir = Rails.root.join("..", ".hats", "qa").to_s
    # Prepend require path so playwright is found
    script = "process.chdir('#{qa_dir}');\nmodule.paths.unshift('#{qa_dir}/node_modules');\n" + script
    File.write(script_path, script)

    output = `node #{script_path} 2>&1`.strip

    # Extract the JSON line from output (skip any non-JSON lines)
    json_line = output.lines.find { |l| l.strip.start_with?("{") }
    begin
      data = JSON.parse(json_line || "{}")
    rescue
      return { status: "fail", rendered: 0, total: 0, failures: ["Playwright script failed: #{output.first(300)}"] }
    end

    results = data["results"] || []
    ok = results.count { |r| r["status"] == "ok" }
    errors = results.select { |r| r["status"] == "error" }
    no_element = results.select { |r| r["status"] == "no_element" }

    failures = []
    errors.first(10).each { |r| failures << "#{r['name']}: #{r['error']}" }
    failures << "#{data['scriptErrors']} script compilation errors" if data["scriptErrors"].to_i > 0
    data["errorSample"]&.each { |e| failures << "  #{e}" }

    {
      status: failures.empty? ? "pass" : "fail",
      rendered: ok,
      total: results.size,
      no_element: no_element.size,
      failures: failures
    }
  end

  # ==========================================================================
  # Layer 4: Visual Fidelity
  # ==========================================================================

  def run_layer4(ds, ff_main, use_frozen: false)
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])

    # Collect default variant node_ids for component sets
    # Extract the actual React name from compiled code (the var X = function declaration)
    components = []
    ff_main.component_sets.order(:name).each do |cs|
      v = cs.default_variant
      compiled = v&.react_code_compiled
      next unless compiled.present?
      # Extract: var ComponentName = function or var ComponentName_cs_NNN__vN = function
      react_name = compiled.match(/var\s+([A-Z][a-zA-Z0-9_]*)\s*=\s*function/)&.captures&.first
      # For multi-variant, use the dispatcher name (without _cs_NNN__vN suffix)
      react_name = react_name&.sub(/_cs_\d+__v\d+$/, "")
      next unless react_name
      components << { name: cs.name, react_name: react_name, node_id: v.node_id, file_key: cs.figma_file_key, type: "set" }
    end
    ff_main.components.where.not(react_code_compiled: [nil, ""]).order(:name).each do |c|
      react_name = c.react_code_compiled.match(/var\s+([A-Z][a-zA-Z0-9_]*)\s*=\s*function/)&.captures&.first
      next unless react_name
      components << { name: c.name, react_name: react_name, node_id: c.node_id, file_key: c.figma_file_key, type: "comp" }
    end

    puts "  Testing #{components.size} components..."

    # Step 1: Get Figma screenshots
    if use_frozen
      puts "  Using frozen Figma screenshots from #{FIXTURES_DIR}"
    else
      puts "  Exporting Figma screenshots..."
      export_figma_screenshots(figma, components)
    end

    # Step 2: Render and screenshot each component in browser
    puts "  Rendering components in browser..."
    render_screenshots(ds, components)

    # Step 3: Compare
    puts "  Comparing..."
    results = compare_screenshots(components, use_frozen: use_frozen)

    pass = results.count { |r| (r[:diff_pixels] || 999999) < 100 }
    fail_count = results.size - pass
    avg_diff = results.any? ? (results.sum { |r| r[:diff_pixels] || 0 } / results.size.to_f).round(1) : 0

    {
      summary: { total: results.size, pass: pass, fail: fail_count, avg_diff: avg_diff },
      components: results
    }
  end

  def export_figma_screenshots(figma, components)
    components.group_by { |c| c[:file_key] }.each do |file_key, items|
      items.each_slice(50) do |batch|
        ids = batch.map { |c| c[:node_id] }
        resp = figma.export_png(file_key, ids, scale: 1)
        images = resp["images"] || {}
        batch.each do |item|
          url = images[item[:node_id]]
          next unless url
          begin
            png = figma.fetch_binary_content(url)
            File.binwrite(OUTPUT_DIR.join("figma_#{safe_name(item[:name])}.png"), png)
          rescue => e
            puts "    WARN: Failed to export #{item[:name]}: #{e.message}"
          end
        end
      end
    end
  end

  def render_screenshots(ds, components)
    # Build a Node.js script that renders each component and takes a screenshot
    # Build mapping of react_name -> safe file name
    items_json = components.map { |c| { react_name: c[:react_name], safe_name: safe_name(c[:name]) } }.to_json

    script = <<~JS
      const { chromium } = require('playwright');
      const fs = require('fs');
      (async () => {
        const browser = await chromium.launch();
        const page = await browser.newPage({ viewport: { width: 1200, height: 800 }, ignoreHTTPSErrors: true });
        await page.goto('https://design-gpt.localtest.me/api/design-systems/#{ds.id}/renderer', { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);
        // Wait for font to load
        await page.evaluate(() => document.fonts.ready);

        const items = #{items_json};
        const results = {};

        for (const { react_name, safe_name } of items) {
          await page.evaluate((rn) => {
            const root = document.getElementById('root');
            // Unmount previous component cleanly to avoid removeChild errors
            try { ReactDOM.unmountComponentAtNode(root); } catch(e) {}
            root.innerHTML = '';
            root.style.padding = '0';
            root.style.background = 'white';
            root.style.display = 'inline-block';
            try {
              if (typeof window[rn] === 'function') {
                ReactDOM.render(React.createElement(window[rn]), root);
              }
            } catch(e) {}
          }, react_name);
          await page.waitForTimeout(200);
          await page.evaluate(() => document.fonts.ready);

          try {
            // Try data-component first for tight crop, then any visible element
            let el = page.locator('[data-component]').first();
            let found = false;
            try { await el.waitFor({ timeout: 500 }); found = true; } catch(e) {}
            if (!found) {
              el = page.locator('#root div').first();
              try { await el.waitFor({ timeout: 500 }); found = true; } catch(e) {}
            }
            if (found) {
              const box = await el.boundingBox();
              if (box && box.width > 0 && box.height > 0) {
                // Use page.screenshot with clip to respect overflow:hidden (el.screenshot captures scroll height)
                await page.screenshot({ path: '#{OUTPUT_DIR}/render_' + safe_name + '.png', clip: { x: box.x, y: box.y, width: box.width, height: box.height } });
                results[safe_name] = { w: Math.round(box.width), h: Math.round(box.height) };
              } else {
                results[safe_name] = { error: 'zero_size' };
              }
            } else {
              // Fallback: check if root has any content at all
              const rootHTML = await page.evaluate(() => document.getElementById('root').innerHTML.trim());
              if (rootHTML.length > 0) {
                // Has content but no visible element — take root screenshot
                const rootBox = await page.locator('#root').boundingBox();
                if (rootBox && rootBox.height > 0) {
                  await page.locator('#root').screenshot({ path: '#{OUTPUT_DIR}/render_' + safe_name + '.png' });
                  results[safe_name] = { w: Math.round(rootBox.width), h: Math.round(rootBox.height), fallback: true };
                } else {
                  results[safe_name] = { error: 'empty_render' };
                }
              } else {
                results[safe_name] = { error: 'no_element' };
              }
            }
          } catch(e) {
            results[safe_name] = { error: e.message.substring(0, 100) };
          }
        }

        fs.writeFileSync('#{OUTPUT_DIR}/render_results.json', JSON.stringify(results));
        console.log('Done: ' + Object.keys(results).filter(k => !results[k].error).length + '/' + items.length);
        await browser.close();
      })();
    JS

    script_path = OUTPUT_DIR.join("visual_test.js")
    qa_dir = Rails.root.join("..", ".hats", "qa").to_s
    script = "process.chdir('#{qa_dir}');\nmodule.paths.unshift('#{qa_dir}/node_modules');\n" + script
    File.write(script_path, script)
    output = `node #{script_path} 2>&1`.strip
    puts "    #{output.lines.last&.strip}"
  end

  def compare_screenshots(components, use_frozen: false)
    results = []

    components.each do |comp|
      name = comp[:name]
      safe = safe_name(name)

      figma_path = if use_frozen
        FIXTURES_DIR.join("#{safe}.png")
      else
        OUTPUT_DIR.join("figma_#{safe}.png")
      end

      render_path = OUTPUT_DIR.join("render_#{safe}.png")

      unless File.exist?(figma_path) && File.exist?(render_path)
        reason = !File.exist?(figma_path) ? "no figma screenshot" : "no render screenshot"
        results << { name: name, diff_pixels: nil, status: "missing", error: reason }
        next
      end

      diff_pixels = pixel_diff(figma_path.to_s, render_path.to_s, DIFF_DIR.join("diff_#{safe}.png").to_s)
      results << { name: name, diff_pixels: diff_pixels, status: diff_pixels < 100 ? "pass" : "fail" }
    end

    results
  end

  def pixel_diff(path_a, path_b, diff_path)
    FileUtils.mkdir_p(File.dirname(diff_path))

    img1 = ChunkyPNG::Image.from_file(path_a)
    img2 = ChunkyPNG::Image.from_file(path_b)

    w = [img1.width, img2.width].min
    h = [img1.height, img2.height].min

    # Center-crop the larger image (Figma exports include shadow padding)
    if img1.width > w || img1.height > h
      ox = (img1.width - w) / 2
      oy = (img1.height - h) / 2
      img1 = img1.crop(ox, oy, w, h)
    end
    if img2.width > w || img2.height > h
      ox = (img2.width - w) / 2
      oy = (img2.height - h) / 2
      img2 = img2.crop(ox, oy, w, h)
    end

    diff_image = ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
    diff_pixels = 0
    threshold = 30

    # Compositing helper: blend with white background (Figma exports with transparency)
    white_blend = ->(c) {
      a = ChunkyPNG::Color.a(c)
      return [255, 255, 255] if a == 0
      return [ChunkyPNG::Color.r(c), ChunkyPNG::Color.g(c), ChunkyPNG::Color.b(c)] if a == 255
      af = a / 255.0
      r = (ChunkyPNG::Color.r(c) * af + 255 * (1 - af)).round
      g = (ChunkyPNG::Color.g(c) * af + 255 * (1 - af)).round
      b = (ChunkyPNG::Color.b(c) * af + 255 * (1 - af)).round
      [r, g, b]
    }

    h.times do |y|
      w.times do |x|
        r1, g1, b1 = white_blend.call(img1[x, y])
        r2, g2, b2 = white_blend.call(img2[x, y])
        dr = (r1 - r2).abs
        dg = (g1 - g2).abs
        db = (b1 - b2).abs

        if dr > threshold || dg > threshold || db > threshold
          diff_pixels += 1
          diff_image[x, y] = ChunkyPNG::Color.rgba(255, 0, 0, 180)
        else
          diff_image[x, y] = ChunkyPNG::Color.rgba((r1 * 0.3).to_i, (g1 * 0.3).to_i, (b1 * 0.3).to_i, 255)
        end
      end
    end

    diff_image.save(diff_path)
    diff_pixels
  rescue => e
    puts "    WARN: pixel_diff failed for #{File.basename(path_a)}: #{e.message}"
    999999
  end

  # ==========================================================================
  # Freeze Figma Screenshots
  # ==========================================================================

  def freeze_figma_screenshots
    FileUtils.mkdir_p(FIXTURES_DIR)
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    ds = DesignSystem.find_by(name: "WM") || DesignSystem.first
    ff = ds.current_figma_files.find_by(figma_file_key: "oL5zKzFeTuZRd2rFMbUJWa")

    components = []
    ff.component_sets.order(:name).each do |cs|
      v = cs.default_variant
      next unless v
      components << { name: cs.name, node_id: v.node_id, file_key: cs.figma_file_key }
    end
    ff.components.order(:name).each do |c|
      components << { name: c.name, node_id: c.node_id, file_key: c.figma_file_key }
    end

    puts "Freezing #{components.size} Figma screenshots to #{FIXTURES_DIR}..."

    components.group_by { |c| c[:file_key] }.each do |file_key, items|
      items.each_slice(50) do |batch|
        ids = batch.map { |c| c[:node_id] }
        resp = figma.export_png(file_key, ids, scale: 1)
        images = resp["images"] || {}
        batch.each do |item|
          url = images[item[:node_id]]
          next unless url
          begin
            png = figma.fetch_binary_content(url)
            dest = FIXTURES_DIR.join("#{safe_name(item[:name])}.png")
            File.binwrite(dest, png)
            puts "  ✓ #{item[:name]}"
          rescue => e
            puts "  ✗ #{item[:name]}: #{e.message}"
          end
        end
      end
    end

    puts "Done. #{components.size} screenshots frozen."
  end

  # ==========================================================================
  # Helpers
  # ==========================================================================

  def safe_name(name)
    name.gsub(/[^a-zA-Z0-9_-]/, "_").gsub(/_+/, "_").gsub(/^_|_$/, "")
  end

  def to_component_name(name)
    name.to_s
      .gsub(/[^a-zA-Z0-9\s]/, " ")
      .split
      .map(&:capitalize)
      .join
      .gsub(/^(\d)/, 'C\1')
      .then { |n| n.empty? ? "Component" : n }
  end

  # ==========================================================================
  # Structural Test: hide text/shadows, compare layout only
  # ==========================================================================

  STRUCTURAL_DIR = OUTPUT_DIR.join("structural")

  STRUCTURAL_CSS = <<~CSS.freeze
    * {
      color: transparent !important;
      -webkit-text-fill-color: transparent !important;
      box-shadow: none !important;
      text-shadow: none !important;
    }
    svg { opacity: 0 !important; }
  CSS

  def run_structural_test
    FileUtils.mkdir_p(STRUCTURAL_DIR)

    ds = DesignSystem.find_by(name: "WM") || DesignSystem.first
    abort "No design system found" unless ds

    ff_main = ds.current_figma_files.find_by(figma_file_key: "oL5zKzFeTuZRd2rFMbUJWa")
    abort "WM FigmaFile not found" unless ff_main

    # Collect components
    components = []
    ff_main.component_sets.order(:name).each do |cs|
      v = cs.default_variant
      compiled = v&.react_code_compiled
      next unless compiled.present?
      react_name = compiled.match(/var\s+([A-Z][a-zA-Z0-9_]*)\s*=\s*function/)&.captures&.first
      react_name = react_name&.sub(/_cs_\d+__v\d+$/, "")
      next unless react_name
      components << { name: cs.name, react_name: react_name, safe: safe_name(cs.name) }
    end
    ff_main.components.where.not(react_code_compiled: [nil, ""]).order(:name).each do |c|
      react_name = c.react_code_compiled.match(/var\s+([A-Z][a-zA-Z0-9_]*)\s*=\s*function/)&.captures&.first
      next unless react_name
      components << { name: c.name, react_name: react_name, safe: safe_name(c.name) }
    end

    puts "=" * 70
    puts "STRUCTURAL DIFF (text/shadows hidden)"
    puts "=" * 70
    puts "Components: #{components.size}"
    puts ""

    # Step 1: Export Figma screenshots (reuse if exist)
    figma_dir = OUTPUT_DIR
    unless Dir.glob(figma_dir.join("figma_*.png")).size > 50
      puts "Exporting Figma screenshots..."
      figma = Figma::TokenPool.instance.primary_client
      export_figma_screenshots(figma, components.map { |c|
        ff = ff_main
        v = ff.component_sets.find_by(name: c[:name])&.default_variant || ff.components.find_by(name: c[:name])
        { name: c[:name], node_id: v&.node_id || "", file_key: ff.figma_file_key, type: "any" }
      }.select { |c| c[:node_id].present? })
    end

    # Step 2: Render with structural CSS (text hidden, no shadows)
    puts "Rendering structural screenshots..."
    render_structural_screenshots(ds, components)

    # Step 3: Compare with downscaled images (4x smaller = text noise disappears)
    puts "Comparing (downscaled 2x)..."
    results = []
    components.each do |comp|
      figma_path = figma_dir.join("figma_#{comp[:safe]}.png")
      render_path = STRUCTURAL_DIR.join("render_#{comp[:safe]}.png")

      unless File.exist?(figma_path) && File.exist?(render_path)
        results << { name: comp[:name], diff: nil, status: "missing" }
        next
      end

      diff = structural_pixel_diff(
        figma_path.to_s, render_path.to_s,
        STRUCTURAL_DIR.join("diff_#{comp[:safe]}.png").to_s
      )
      results << { name: comp[:name], diff: diff, status: diff < 50 ? "pass" : "fail" }
    end

    # Report
    results.sort_by! { |r| r[:diff] || 999999 }
    compared = results.select { |r| r[:diff] }
    pass = compared.count { |r| r[:status] == "pass" }

    puts ""
    puts "PASS (<50px structural diff): #{pass}/#{compared.size}"
    puts "FAIL: #{compared.size - pass}"
    puts ""

    # Show worst structural issues (these are REAL layout bugs, not font diffs)
    puts "Structural issues (layout/color/size bugs):"
    compared.select { |r| r[:diff] >= 50 }.last(20).reverse.each do |r|
      puts "  #{r[:diff]}px  #{r[:name]}"
    end

    puts ""
    puts "Perfect structural match:"
    compared.select { |r| r[:diff] < 50 }.first(20).each do |r|
      puts "  #{r[:diff]}px  #{r[:name]}"
    end

    File.write(STRUCTURAL_DIR.join("report.json"), JSON.pretty_generate({
      timestamp: Time.now.iso8601,
      total: components.size,
      compared: compared.size,
      pass: pass,
      results: results
    }))
    puts "\nReport: #{STRUCTURAL_DIR.join("report.json")}"
  end

  def render_structural_screenshots(ds, components)
    items_json = components.map { |c| { react_name: c[:react_name], safe_name: c[:safe] } }.to_json
    qa_dir = Rails.root.join("..", ".hats", "qa").to_s

    script = <<~JS
      process.chdir('#{qa_dir}');
      module.paths.unshift('#{qa_dir}/node_modules');
      const { chromium } = require('playwright');
      const fs = require('fs');
      (async () => {
        const browser = await chromium.launch();
        const page = await browser.newPage({ viewport: { width: 1200, height: 800 }, ignoreHTTPSErrors: true });
        await page.goto('https://design-gpt.localtest.me/api/design-systems/#{ds.id}/renderer', { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);

        // Inject structural CSS: hide text and shadows
        await page.addStyleTag({ content: `#{STRUCTURAL_CSS.gsub("\n", " ")}` });

        const items = #{items_json};
        let done = 0;

        for (const { react_name, safe_name } of items) {
          await page.evaluate((rn) => {
            const root = document.getElementById('root');
            try { ReactDOM.unmountComponentAtNode(root); } catch(e) {}
            root.innerHTML = '';
            root.style.padding = '0';
            root.style.background = 'white';
            root.style.display = 'inline-block';
            try {
              if (typeof window[rn] === 'function') {
                ReactDOM.render(React.createElement(window[rn]), root);
              }
            } catch(e) {}
          }, react_name);
          await page.waitForTimeout(100);

          try {
            let el = page.locator('[data-component]').first();
            let found = false;
            try { await el.waitFor({ timeout: 500 }); found = true; } catch(e) {}
            if (!found) {
              el = page.locator('#root div').first();
              try { await el.waitFor({ timeout: 300 }); found = true; } catch(e) {}
            }
            if (found) {
              const box = await el.boundingBox();
              if (box && box.width > 0 && box.height > 0) {
                await page.screenshot({ path: '#{STRUCTURAL_DIR}/' + 'render_' + safe_name + '.png', clip: { x: box.x, y: box.y, width: box.width, height: box.height } });
                done++;
              }
            }
          } catch(e) {}
        }

        console.log('Done: ' + done + '/' + items.length);
        await browser.close();
      })();
    JS

    script_path = STRUCTURAL_DIR.join("structural_test.js")
    File.write(script_path, script)
    output = `node #{script_path} 2>&1`.strip
    puts "  #{output.lines.last&.strip}"
  end

  # Structural pixel diff: downscale 2x before comparing to blur away text noise
  def structural_pixel_diff(path_a, path_b, diff_path)
    FileUtils.mkdir_p(File.dirname(diff_path))

    img1 = ChunkyPNG::Image.from_file(path_a)
    img2 = ChunkyPNG::Image.from_file(path_b)

    # Center-crop larger image
    w = [img1.width, img2.width].min
    h = [img1.height, img2.height].min
    if img1.width > w || img1.height > h
      img1 = img1.crop((img1.width - w) / 2, (img1.height - h) / 2, w, h)
    end
    if img2.width > w || img2.height > h
      img2 = img2.crop((img2.width - w) / 2, (img2.height - h) / 2, w, h)
    end

    # Downscale 2x (averages 2x2 blocks, blurs text)
    sw = w / 2
    sh = h / 2
    return 0 if sw == 0 || sh == 0

    white_blend = ->(c) {
      a = ChunkyPNG::Color.a(c)
      return [255, 255, 255] if a == 0
      return [ChunkyPNG::Color.r(c), ChunkyPNG::Color.g(c), ChunkyPNG::Color.b(c)] if a == 255
      af = a / 255.0
      [(ChunkyPNG::Color.r(c) * af + 255 * (1 - af)).round,
       (ChunkyPNG::Color.g(c) * af + 255 * (1 - af)).round,
       (ChunkyPNG::Color.b(c) * af + 255 * (1 - af)).round]
    }

    avg_pixel = ->(img, x, y) {
      r = g = b = 0
      count = 0
      [0, 1].each { |dy| [0, 1].each { |dx|
        px = x * 2 + dx; py = y * 2 + dy
        next if px >= img.width || py >= img.height
        cr, cg, cb = white_blend.call(img[px, py])
        r += cr; g += cg; b += cb; count += 1
      }}
      count > 0 ? [r / count, g / count, b / count] : [255, 255, 255]
    }

    diff_image = ChunkyPNG::Image.new(sw, sh)
    diff_pixels = 0
    threshold = 40  # Higher threshold for structural (ignores subtle color shifts)

    sh.times do |y|
      sw.times do |x|
        r1, g1, b1 = avg_pixel.call(img1, x, y)
        r2, g2, b2 = avg_pixel.call(img2, x, y)
        dr = (r1 - r2).abs
        dg = (g1 - g2).abs
        db = (b1 - b2).abs

        if dr > threshold || dg > threshold || db > threshold
          diff_pixels += 1
          diff_image[x, y] = ChunkyPNG::Color.rgba(255, 0, 0, 200)
        else
          diff_image[x, y] = ChunkyPNG::Color.rgba((r1 * 0.4).to_i, (g1 * 0.4).to_i, (b1 * 0.4).to_i, 255)
        end
      end
    end

    diff_image.save(diff_path)
    diff_pixels
  rescue => e
    puts "    WARN: structural diff failed for #{File.basename(path_a)}: #{e.message}"
    999999
  end
end
