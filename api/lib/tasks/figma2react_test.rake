require "fileutils"
$stdout.sync = true

# Logger that writes to both stdout and a log file
class TestLogger
  LOG_DIR = Rails.root.join("tmp", "figma2react_test")

  def initialize
    FileUtils.mkdir_p(LOG_DIR)
    @log_path = LOG_DIR.join("test_run.log")
    @log_file = File.open(@log_path, "w")
    @log_file.sync = true
  end

  def log(msg = "")
    line = msg.to_s
    puts line
    @log_file.puts(line)
  end

  def close
    @log_file.close if @log_file
  end

  def path
    @log_path
  end
end

namespace :figma2react do
  # Test cases page in Figma - all root frames on this page will be tested
  TEST_PAGE_URL = "https://www.figma.com/design/kKZSOaxB2TF5U83dQ8GYwT/test-cases?node-id=0-1".freeze
  TEST_FILE_KEY = "kKZSOaxB2TF5U83dQ8GYwT".freeze
  TEST_PAGE_NODE_ID = "0:1".freeze

  REFERENCES_DIR = Rails.root.join("test", "figma2react", "references")
  CACHE_DIR = Rails.root.join("tmp", "figma2react_cache")
  OUTPUT_DIR = Rails.root.join("tmp", "figma2react_test")

  desc "Run all Figma to HTML visual tests from test-cases page"
  task test_all: :environment do
    logger = TestLogger.new
    logger.log "Log file: #{logger.path}"
    logger.log "Started at: #{Time.now.iso8601}"
    logger.log

    test_cases = load_test_cases(logger: logger)

    logger.log "=" * 70
    logger.log "FIGMA TO HTML VISUAL TEST SUITE"
    logger.log "=" * 70
    logger.log "Test page: #{TEST_PAGE_URL}"
    logger.log "Found #{test_cases.size} test case(s)\n\n"

    # Phase 1: Validate ALL tests first
    logger.log "=" * 70
    logger.log "PHASE 1: VALIDATION"
    logger.log "=" * 70

    validation_errors = {}
    test_cases.each_with_index do |test_case, idx|
      name = test_case[:name]
      errors = validate_test(test_case, idx + 1, logger: logger)
      if errors.any?
        validation_errors[name] = errors
        logger.log "  [#{idx + 1}/#{test_cases.size}] ✗ #{name}"
        errors.each { |e| logger.log "    #{e}" }
      else
        logger.log "  [#{idx + 1}/#{test_cases.size}] ✓ #{name}"
      end
    end

    if validation_errors.any?
      logger.log "\nVALIDATION FAILED — #{validation_errors.size} test(s) have issues. Fix them in Figma, then re-run."
      logger.log "\nFinished at: #{Time.now.iso8601}"
      logger.close
      exit(1)
    end

    logger.log "\n✓ All #{test_cases.size} test(s) passed validation\n"

    # Phase 2: Run ALL tests
    logger.log "=" * 70
    logger.log "PHASE 2: VISUAL TESTS"
    logger.log "=" * 70

    results = {}
    test_cases.each_with_index do |test_case, idx|
      name = test_case[:name]
      logger.log "-" * 70
      logger.log "[#{idx + 1}/#{test_cases.size}] #{name}"
      logger.log "-" * 70

      result = run_test(test_case, idx + 1, logger: logger)
      results[name] = result

      if result[:success]
        diff_info = result[:diff_percent] ? " (diff: #{result[:diff_percent]}%)" : ""
        logger.log "PASSED#{diff_info}\n\n"
      else
        logger.log "FAILED: #{result[:error]}\n\n"
      end
    end

    print_summary(results, logger: logger)

    # Save results so test_failed can pick up where we left off
    save_last_results(results, test_cases)

    logger.log "\nFinished at: #{Time.now.iso8601}"
    logger.close

    failed = results.count { |_, r| !r[:success] }
    exit(1) if failed > 0
  end

  desc "Re-run the first failed test from the last test_all run"
  task test_failed: :environment do
    logger = TestLogger.new
    last_results, test_cases_map = load_last_results

    unless last_results
      logger.log "No previous test_all results found. Run figma2react:test_all first."
      logger.close
      exit 1
    end

    # Find the first failed test
    failed_name = last_results.find { |_, r| !r["success"] }&.first

    unless failed_name
      logger.log "All tests passed in the last run! Nothing to re-run."
      logger.close
      exit 0
    end

    test_case = test_cases_map[failed_name]
    unless test_case
      logger.log "Test case '#{failed_name}' not found. Run figma2react:test_all to refresh."
      logger.close
      exit 1
    end

    logger.log "=" * 70
    logger.log "Re-running first failure: #{failed_name}"
    logger.log "=" * 70

    result = run_test(test_case, 1, logger: logger)

    if result[:success]
      diff_info = result[:diff_percent] ? " (diff: #{result[:diff_percent]}%)" : ""
      logger.log "\nPASSED#{diff_info}"
    else
      logger.log "\nFAILED: #{result[:error]}"
    end

    logger.log "\nComparison: file://#{result[:comparison_path]}"
    logger.log "=" * 70
    logger.close
    exit(result[:success] ? 0 : 1)
  end

  desc "Run a specific test by name or index"
  task :test, [:identifier] => :environment do |t, args|
    logger = TestLogger.new
    identifier = args[:identifier]
    test_cases = load_test_cases(logger: logger)

    if identifier.blank?
      logger.log "Usage: rake figma2react:test[NAME] or rake figma2react:test[INDEX]"
      logger.log "\nAvailable tests:"
      test_cases.each_with_index { |tc, i| logger.log "  #{i + 1}. #{tc[:name]}" }
      logger.close
      exit 1
    end

    # Find test case by index or name
    test_case, idx = if identifier.match?(/^\d+$/)
      i = identifier.to_i - 1
      if i < 0 || i >= test_cases.size
        logger.log "Invalid index: #{identifier}. Valid range: 1-#{test_cases.size}"
        logger.close
        exit 1
      end
      [test_cases[i], i]
    else
      tc = test_cases.find { |t| t[:name] == identifier }
      unless tc
        logger.log "Test not found: #{identifier}"
        logger.log "\nAvailable tests:"
        test_cases.each_with_index { |t, i| logger.log "  #{i + 1}. #{t[:name]}" }
        logger.close
        exit 1
      end
      [tc, test_cases.index(tc)]
    end

    logger.log "=" * 70
    logger.log "Testing: #{test_case[:name]}"
    logger.log "=" * 70

    # Validate first
    errors = validate_test(test_case, idx + 1, logger: logger)
    if errors.any?
      logger.log "\nVALIDATION FAILED:"
      errors.each { |e| logger.log "  #{e}" }
      logger.log "=" * 70
      logger.close
      exit 1
    end

    result = run_test(test_case, idx + 1, logger: logger)

    if result[:success]
      diff_info = result[:diff_percent] ? " (diff: #{result[:diff_percent]}%)" : ""
      logger.log "\nPASSED#{diff_info}"
    else
      logger.log "\nFAILED: #{result[:error]}"
    end

    logger.log "\nComparison: file://#{result[:comparison_path]}"
    logger.log "=" * 70
    logger.close
  end

  desc "List available test cases"
  task list: :environment do
    logger = TestLogger.new
    test_cases = load_test_cases(logger: logger)
    logger.log "Available test cases from Figma:\n\n"
    test_cases.each_with_index do |tc, idx|
      logger.log "#{idx + 1}. #{tc[:name]} (node: #{tc[:node_id]}, #{tc[:width]}x#{tc[:height]})"
    end
    logger.log "\nTotal: #{test_cases.size} test case(s)"
    logger.close
  end

  desc "Refresh test cases from Figma (clear page cache)"
  task refresh: :environment do
    logger = TestLogger.new
    cache_file = CACHE_DIR.join("nodes", "#{TEST_FILE_KEY}_#{TEST_PAGE_NODE_ID.gsub(':', '-')}.json")
    if File.exist?(cache_file)
      FileUtils.rm(cache_file)
      logger.log "Page cache cleared"
    end
    
    test_cases = load_test_cases(use_cache: false, logger: logger)
    logger.log "Found #{test_cases.size} test cases:"
    test_cases.each { |tc| logger.log "  - #{tc[:name]}" }
    logger.close
  end

  desc "Clear all caches"
  task clear_cache: :environment do
    if Dir.exist?(CACHE_DIR)
      FileUtils.rm_rf(CACHE_DIR)
      puts "Cache cleared: #{CACHE_DIR}"
    else
      puts "No cache to clear"
    end
  end

  desc "Show cache stats"
  task cache_stats: :environment do
    unless Dir.exist?(CACHE_DIR)
      puts "No cache directory found"
      next
    end

    files = Dir.glob(CACHE_DIR.join("**", "*")).select { |f| File.file?(f) }
    total_size = files.sum { |f| File.size(f) }

    puts "Cache Statistics:"
    puts "  Location: #{CACHE_DIR}"
    puts "  Files: #{files.size}"
    puts "  Total size: #{(total_size / 1024.0).round(1)} KB"

    puts "\nCached items:"
    files.group_by { |f| File.dirname(f).split("/").last }.each do |type, type_files|
      puts "  #{type}: #{type_files.size} files"
    end
  end

  # ============================================
  # Helper Methods
  # ============================================

  def load_test_cases(use_cache: true, logger: nil)
    logger ||= TestLogger.new
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    
    FileUtils.mkdir_p(CACHE_DIR.join("nodes"))
    cache_file = CACHE_DIR.join("nodes", "#{TEST_FILE_KEY}_#{TEST_PAGE_NODE_ID.gsub(':', '-')}.json")

    # Fetch page data
    page_data = if use_cache && cache_valid?(cache_file)
      logger.log "Loading test cases (cached)..."
      JSON.parse(File.read(cache_file))
    else
      logger.log "Fetching test cases from Figma..."
      response = figma.nodes(TEST_FILE_KEY, TEST_PAGE_NODE_ID)
      node_data = response.dig("nodes", TEST_PAGE_NODE_ID, "document")
      
      if node_data.nil?
        raise "Could not fetch test page: #{TEST_PAGE_URL}"
      end
      
      File.write(cache_file, JSON.generate(node_data))
      node_data
    end

    # Find all test frames on the page (including inside SECTIONs)
    children = page_data["children"] || []
    test_frames = []
    children.each do |child|
      if child["type"] == "FRAME"
        test_frames << child
      elsif child["type"] == "SECTION"
        # Look inside sections for frames
        (child["children"] || []).each do |grandchild|
          test_frames << grandchild if grandchild["type"] == "FRAME"
        end
      end
    end

    # Sort by name for consistent ordering
    test_frames.sort_by { |f| f["name"] }.map do |frame|
      {
        name: frame["name"],
        node_id: frame["id"],
        width: frame.dig("absoluteBoundingBox", "width")&.to_i,
        height: frame.dig("absoluteBoundingBox", "height")&.to_i
      }
    end
  end

  def validate_test(test_case, index, logger: nil)
    logger ||= TestLogger.new
    tester = Figma2HtmlTester.new(
      name: test_case[:name],
      file_key: TEST_FILE_KEY,
      node_id: test_case[:node_id],
      index: index,
      logger: logger
    )
    tester.validate
  rescue => e
    ["ERROR: #{e.message}"]
  end

  def run_test(test_case, index, logger: nil)
    logger ||= TestLogger.new
    tester = Figma2HtmlTester.new(
      name: test_case[:name],
      file_key: TEST_FILE_KEY,
      node_id: test_case[:node_id],
      index: index,
      logger: logger
    )
    tester.run_test
  rescue => e
    logger.log "ERROR: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    { success: false, error: e.message, comparison_path: OUTPUT_DIR.join("comparison.html") }
  end

  def cache_valid?(file_path)
    return false unless File.exist?(file_path)
    cache_ttl = ENV.fetch("FIGMA_CACHE_TTL", 86400).to_i
    (Time.now - File.mtime(file_path)) < cache_ttl
  end

  def print_summary(results, logger: nil)
    logger ||= TestLogger.new
    logger.log "=" * 70
    logger.log "SUMMARY"
    logger.log "=" * 70
    
    passed = results.count { |_, r| r[:success] }
    failed = results.count { |_, r| !r[:success] }
    
    logger.log "Passed: #{passed}/#{results.size}"
    logger.log "Failed: #{failed}/#{results.size}"

    logger.log "\nVisual Diff Results:"
    results.each_with_index do |(name, r), idx|
      num = format("%02d", idx + 1)
      if r[:success] && r[:diff_percent]
        status = r[:diff_percent] <= 5.0 ? "PASS" : "WARN"
        logger.log "  #{num}. [#{status}] #{r[:diff_percent]}% - #{name}"
      elsif r[:success]
        logger.log "  #{num}. [PASS] (no diff) - #{name}"
      else
        logger.log "  #{num}. [FAIL] - #{name}"
      end
    end

    if failed > 0
      logger.log "\nFailed tests:"
      results.select { |_, r| !r[:success] }.each do |name, r|
        logger.log "  - #{name}: #{r[:error]}"
      end
    end

    logger.log "\nReference screenshots: #{REFERENCES_DIR}"
    logger.log "Comparison page: file://#{OUTPUT_DIR.join("comparison.html")}"
    logger.log "=" * 70
  end

  LAST_RESULTS_FILE = OUTPUT_DIR.join("last_results.json")

  def save_last_results(results, test_cases)
    data = {
      "results" => results.transform_values { |r| { "success" => r[:success], "error" => r[:error], "diff_percent" => r[:diff_percent] } },
      "test_cases" => test_cases.map { |tc| { "name" => tc[:name], "node_id" => tc[:node_id], "width" => tc[:width], "height" => tc[:height] } }
    }
    File.write(LAST_RESULTS_FILE, JSON.pretty_generate(data))
  end

  def load_last_results
    return [nil, nil] unless File.exist?(LAST_RESULTS_FILE)

    data = JSON.parse(File.read(LAST_RESULTS_FILE))
    results = data["results"]
    test_cases_map = data["test_cases"].each_with_object({}) do |tc, h|
      h[tc["name"]] = { name: tc["name"], node_id: tc["node_id"], width: tc["width"], height: tc["height"] }
    end
    [results, test_cases_map]
  rescue => e
    [nil, nil]
  end
end

# ============================================
# Test Runner Class
# ============================================

class Figma2HtmlTester
  REFERENCES_DIR = Rails.root.join("test", "figma2react", "references")
  CACHE_DIR = Rails.root.join("tmp", "figma2react_cache")
  OUTPUT_DIR = Rails.root.join("tmp", "figma2react_test")
  CACHE_TTL = ENV.fetch("FIGMA_CACHE_TTL", 86400).to_i

  def initialize(name:, file_key:, node_id:, index: nil, logger: nil)
    @name = name
    @file_key = file_key
    @node_id = node_id
    @index = index
    @logger = logger || TestLogger.new
    @figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    @file_basename = build_file_basename
    
    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(REFERENCES_DIR)
    FileUtils.mkdir_p(CACHE_DIR.join("nodes"))
    FileUtils.mkdir_p(CACHE_DIR.join("images"))
    FileUtils.mkdir_p(CACHE_DIR.join("exports"))
    FileUtils.mkdir_p(CACHE_DIR.join("svgs"))
    FileUtils.mkdir_p(CACHE_DIR.join("pngs"))
  end

  # Validate the test frame without running the visual diff.
  # Returns an array of error strings (empty = valid).
  def validate
    figma_json = fetch_figma_node
    errors = []

    # Check for forbidden node types (instances/components)
    forbidden = find_forbidden_nodes(figma_json)
    forbidden.each do |f|
      errors << "#{f[:type]} \"#{f[:name]}\" → #{figma_node_url(f[:id])}"
    end

    # Check for containers with image fills + children
    image_containers = find_image_containers(figma_json)
    image_containers.each do |f|
      errors << "IMAGE container \"#{f[:name]}\" has children → #{figma_node_url(f[:id])}"
    end

    # Check for GLASS effects (not fully reproducible in CSS)
    glass_nodes = find_glass_effect_nodes(figma_json)
    glass_nodes.each do |f|
      errors << "GLASS effect on \"#{f[:name]}\" → #{figma_node_url(f[:id])}"
    end

    # Check for children overflowing their parent's fixed size
    overflow_nodes = find_overflowing_children(figma_json)
    overflow_nodes.each do |f|
      errors << "Children overflow \"#{f[:name]}\" (#{f[:children_total].round}px > #{f[:parent_size].round}px in #{f[:axis]}) → #{figma_node_url(f[:id])}"
    end

    # Check for skewed/distorted nodes (plugins can apply arbitrary affine transforms
    # that CSS can't reproduce — we only support pure rotation)
    skewed_nodes = find_skewed_nodes(figma_json)
    skewed_nodes.each do |f|
      errors << "Skewed/distorted node \"#{f[:name]}\" → #{figma_node_url(f[:id])}"
    end

    # Check for auto-layout with WRAP — flex-wrap renders unpredictably
    # wrap_nodes = find_wrap_layout_nodes(figma_json)
    # wrap_nodes.each do |f|
    #   errors << "Auto-layout WRAP on \"#{f[:name]}\" → #{figma_node_url(f[:id])}"
    # end

    errors
  end

  def run_test
    log "\n[1/5] Fetching Figma node..."
    figma_json = fetch_figma_node
    log "  ✓ #{figma_json['name']} (#{figma_json['type']})"

    log "\n[2/5] Fetching images..."
    image_urls = fetch_images(figma_json)
    log "  ✓ #{image_urls.size} images"

    log "\n[3/5] Converting to HTML..."
    converter = Figma::HtmlConverter.new(figma_json, figma_client: @figma, file_key: @file_key)
    converter.set_image_urls(image_urls)
    result = converter.convert

    if result[:error]
      return { success: false, error: result[:error], comparison_path: OUTPUT_DIR.join("comparison.html") }
    end

    log "  ✓ Generated #{result[:component_name]}"

    # Always save generated HTML with proper naming convention
    html_dest = REFERENCES_DIR.join("#{@file_basename}_html.html")
    File.write(html_dest, result[:full_html])
    log "  ✓ Saved: #{html_dest}"

    log "\n[4/5] Generating comparison..."
    comparison_path = generate_comparison_html(result, figma_json)
    log "  ✓ #{comparison_path}"

    log "\n[5/5] Running visual diff..."
    diff_result = run_visual_diff(comparison_path)

    # Always save screenshots with proper naming convention
    save_reference_screenshots(diff_result)
    
    if diff_result[:success]
      log "  ✓ Diff: #{diff_result[:diff_percent]}%"

      {
        success: true,
        comparison_path: comparison_path,
        diff_percent: diff_result[:diff_percent],
        figma_screenshot: diff_result[:figma_screenshot],
        html_screenshot: diff_result[:html_screenshot]
      }
    else
      log "  ✗ Visual diff failed: #{diff_result[:error]}"
      {
        success: false,
        error: "Visual diff failed: #{diff_result[:error]}",
        comparison_path: comparison_path,
        diff_percent: diff_result[:diff_percent]
      }
    end
  end

  private

  def log(msg = "")
    @logger.log(msg)
  end

  def fetch_figma_node
    cache_key = "#{@file_key}_#{@node_id.gsub(':', '-')}"
    cache_file = CACHE_DIR.join("nodes", "#{cache_key}.json")

    if cache_valid?(cache_file)
      log "  (cached)"
      return JSON.parse(File.read(cache_file))
    end

    response = @figma.nodes(@file_key, @node_id)
    node_data = response.dig("nodes", @node_id)

    if node_data.nil?
      raise "Node not found: #{@node_id}"
    end

    document = node_data["document"]
    File.write(cache_file, JSON.generate(document))
    File.write(OUTPUT_DIR.join("figma_node.json"), JSON.pretty_generate(document))

    document
  end

  def fetch_images(figma_json)
    refs = collect_image_refs(figma_json)
    return {} if refs.empty?

    cache_file = CACHE_DIR.join("images", "#{@file_key}_images.json")

    all_images = if cache_valid?(cache_file)
      log "  (cached)"
      JSON.parse(File.read(cache_file))
    else
      image_response = @figma.get("/v1/files/#{@file_key}/images")
      images = image_response.dig("meta", "images") || {}
      File.write(cache_file, JSON.generate(images))
      images
    end

    refs.each_with_object({}) { |ref, h| h[ref] = all_images[ref] if all_images[ref] }
  end

  def collect_image_refs(node, refs = [])
    return refs unless node.is_a?(Hash)
    (node["fills"] || []).each { |f| refs << f["imageRef"] if f["type"] == "IMAGE" && f["imageRef"] }
    (node["children"] || []).each { |c| collect_image_refs(c, refs) }
    refs.uniq
  end

  def export_figma_image_url
    cache_key = "#{@file_key}_#{@node_id.gsub(':', '-')}"
    cache_file = CACHE_DIR.join("exports", "#{cache_key}.txt")

    if cache_valid?(cache_file)
      return File.read(cache_file).strip
    end

    response = @figma.get("/v1/images/#{@file_key}?ids=#{URI.encode_www_form_component(@node_id)}&format=png&scale=1")
    url = response.dig("images", @node_id)

    File.write(cache_file, url) if url
    url
  end

  def generate_comparison_html(result, figma_json)
    width = figma_json.dig("absoluteBoundingBox", "width").to_i
    height = figma_json.dig("absoluteBoundingBox", "height").to_i
    original_url = export_figma_image_url

    html = build_comparison_html(result, original_url, width, height)
    path = OUTPUT_DIR.join("comparison.html")
    File.write(path, html)
    path
  end

  def run_visual_diff(comparison_path)
    Figma::VisualDiff.compare(comparison_path, output_dir: OUTPUT_DIR)
  end

  def save_reference_screenshots(diff_result)
    figma_src = diff_result[:figma_screenshot]
    html_src = diff_result[:html_screenshot]

    if figma_src && File.exist?(figma_src.to_s)
      figma_dest = REFERENCES_DIR.join("#{@file_basename}_figma.png")
      FileUtils.cp(figma_src, figma_dest)
      log "  ✓ Saved: #{figma_dest}"
    end

    if html_src && File.exist?(html_src.to_s)
      html_png_dest = REFERENCES_DIR.join("#{@file_basename}_html.png")
      FileUtils.cp(html_src, html_png_dest)
      log "  ✓ Saved: #{html_png_dest}"
    end
  end

  # Recursively find INSTANCE and COMPONENT nodes in the tree
  # These are forbidden in test frames to ensure we test pure frame conversion
  FORBIDDEN_TYPES = %w[INSTANCE COMPONENT COMPONENT_SET].freeze

  def find_forbidden_nodes(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    # Check children (not the root node itself, which is always a FRAME)
    (node["children"] || []).each do |child|
      if FORBIDDEN_TYPES.include?(child["type"])
        results << { type: child["type"], name: child["name"], id: child["id"] }
      end
      find_forbidden_nodes(child, results)
    end

    results
  end

  # Find nodes that have IMAGE fills AND children — these can't be properly
  # rendered as CSS backgrounds (export would include children).
  # Test frames should use leaf shapes for images instead.
  def find_image_containers(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    children = node["children"] || []
    fills = node["fills"] || []
    has_image_fill = fills.any? { |f| f["type"] == "IMAGE" && f["visible"] != false }

    if has_image_fill && children.any?
      results << { name: node["name"], id: node["id"], type: node["type"] }
    end

    children.each { |child| find_image_containers(child, results) }

    results
  end

  # Find nodes that have a GLASS effect — this Figma material can't be fully
  # reproduced in CSS (backdrop-filter is an approximation, but noise/specular
  # highlights are missing). Test frames should avoid GLASS for accurate diffs.
  def find_glass_effect_nodes(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    effects = node["effects"] || []
    has_glass = effects.any? { |e| e["type"] == "GLASS" && e["visible"] != false }

    if has_glass
      results << { name: node["name"], id: node["id"] }
    end

    (node["children"] || []).each { |child| find_glass_effect_nodes(child, results) }

    results
  end

  # Find auto-layout containers where a FIXED-size child is as wide/tall as
  # (or wider than) the parent, leaving no room for siblings. Figma renders
  # these "forgivingly" but CSS strictly clips/overflows.
  # We only flag FIXED children (not HUG) because HUG overflow is usually
  # intentional (scrollable tab bars, horizontal lists, etc.).
  def find_overflowing_children(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    layout_mode = node["layoutMode"]
    children = node["children"] || []

    if layout_mode && !node["clipsContent"]
      horizontal = layout_mode == "HORIZONTAL"
      axis = horizontal ? "width" : "height"

      bbox = node["absoluteBoundingBox"] || {}
      parent_size = horizontal ? bbox["width"] : bbox["height"]

      if parent_size && parent_size > 0
        flow_children = children.select { |c|
          c["visible"] != false &&
          c["layoutPositioning"] != "ABSOLUTE" &&
          c["layoutPositioning"] != "FIXED"
        }

        if flow_children.size > 1
          # Account for padding
          padding_start = horizontal ? (node["paddingLeft"] || 0) : (node["paddingTop"] || 0)
          padding_end = horizontal ? (node["paddingRight"] || 0) : (node["paddingBottom"] || 0)
          available = parent_size - padding_start - padding_end

          # Check if any FIXED child >= parent available size (leaving no room for siblings)
          has_oversized_fixed = flow_children.any? { |c|
            sizing = horizontal ? c["layoutSizingHorizontal"] : c["layoutSizingVertical"]
            next false unless sizing == "FIXED"

            child_bbox = c["absoluteBoundingBox"] || {}
            child_size = (horizontal ? child_bbox["width"] : child_bbox["height"]) || 0
            child_size >= available - 1 # -1px tolerance for rounding
          }

          if has_oversized_fixed
            children_total = flow_children.sum { |c|
              child_bbox = c["absoluteBoundingBox"] || {}
              sizing = horizontal ? c["layoutSizingHorizontal"] : c["layoutSizingVertical"]
              sizing == "FILL" ? 0 : ((horizontal ? child_bbox["width"] : child_bbox["height"]) || 0)
            }
            gap = node["itemSpacing"] || 0
            total_gaps = gap > 0 ? gap * (flow_children.size - 1) : 0
            children_with_gaps = children_total + total_gaps

            results << {
              name: node["name"],
              id: node["id"],
              axis: axis,
              parent_size: parent_size,
              children_total: children_with_gaps
            }
          end
        end
      end
    end

    children.each { |child| find_overflowing_children(child, results) }

    results
  end

  # Find nodes with skewed/distorted transforms. Figma plugins can apply
  # arbitrary affine transforms (shear/skew) via relativeTransform, but we
  # only support pure rotation in CSS. A valid rotation matrix has perpendicular
  # columns of equal length; if that doesn't hold, the node is skewed.
  SKEW_TOLERANCE = 0.01

  def find_skewed_nodes(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    transform = node["relativeTransform"]
    if transform.is_a?(Array) && transform.length >= 2
      a = transform[0][0].to_f  # col1.x
      b = transform[0][1].to_f  # col2.x
      c = transform[1][0].to_f  # col1.y
      d = transform[1][1].to_f  # col2.y

      # Column lengths (should be equal for rotation / uniform scale)
      len1 = Math.sqrt(a * a + c * c)
      len2 = Math.sqrt(b * b + d * d)

      # Dot product of columns (should be 0 for perpendicular axes)
      dot = a * b + c * d

      lengths_match = (len1 - len2).abs < SKEW_TOLERANCE
      perpendicular = dot.abs < SKEW_TOLERANCE

      unless lengths_match && perpendicular
        results << { name: node["name"], id: node["id"] }
      end
    end

    (node["children"] || []).each { |child| find_skewed_nodes(child, results) }

    results
  end

  # Find auto-layout containers that use WRAP. Flex-wrap causes unpredictable
  # rendering differences between Figma and CSS because line-breaking heuristics
  # differ, so test frames should avoid it.
  def find_wrap_layout_nodes(node, results = [])
    return results unless node.is_a?(Hash)
    return results if node["visible"] == false

    if node["layoutWrap"] == "WRAP"
      results << { name: node["name"], id: node["id"] }
    end

    (node["children"] || []).each { |child| find_wrap_layout_nodes(child, results) }

    results
  end

  def figma_node_url(node_id)
    encoded = node_id.to_s.gsub(":", "-")
    "https://www.figma.com/design/#{@file_key}?node-id=#{encoded}"
  end

  def build_file_basename
    sanitized_node_id = @node_id.gsub(":", "-")
    sanitized_name = sanitize_name(@name)
    "#{sanitized_node_id}_#{sanitized_name}"
  end

  def sanitize_name(name)
    # Remove emoji and special unicode characters, keep letters, digits, spaces, dashes
    cleaned = name.encode("UTF-8")
      .gsub(/[\u{1F000}-\u{1FFFF}]/, "")  # emoticons & symbols
      .gsub(/[\u{2600}-\u{27BF}]/, "")     # misc symbols
      .gsub(/[\u{FE00}-\u{FE0F}]/, "")     # variation selectors
      .gsub(/[\u{200D}]/, "")              # zero-width joiner
      .gsub(/[^\p{L}\p{N}\s\-]/, "")       # keep only letters, digits, spaces, dashes
      .strip
      .gsub(/\s+/, "-")                     # spaces to dashes
      .gsub(/-{2,}/, "-")                   # collapse multiple dashes
      .downcase
    cleaned.empty? ? "unnamed" : cleaned
  end

  def cache_valid?(file_path)
    return false unless File.exist?(file_path)
    (Time.now - File.mtime(file_path)) < CACHE_TTL
  end

  def build_comparison_html(result, original_url, width, height)
    generated_styles = <<~CSS
      #{result[:font_css]}
      #{result[:css]}
    CSS

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>Figma2HTML Test - #{@name}</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0f0f14; 
            color: #fff;
            min-height: 100vh;
          }
          .header {
            padding: 16px 24px;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            border-bottom: 1px solid #2a2a4a;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .header h1 { font-size: 18px; font-weight: 600; }
          .header h1 span { color: #4ecca3; }
          .test-name { color: #808080; font-size: 14px; }
          .controls {
            padding: 12px 24px;
            background: #16213e;
            display: flex;
            gap: 24px;
            align-items: center;
            flex-wrap: wrap;
          }
          .control-group { display: flex; align-items: center; gap: 8px; }
          .control-group label { font-size: 13px; color: #a0a0a0; }
          .control-group input[type="range"] { width: 120px; }
          .control-group input[type="checkbox"] { width: 16px; height: 16px; }
          .btn {
            padding: 8px 16px;
            border-radius: 6px;
            border: 1px solid #4ecca3;
            background: transparent;
            color: #4ecca3;
            font-size: 13px;
            cursor: pointer;
            transition: all 0.2s;
          }
          .btn:hover { background: #4ecca3; color: #0f0f14; }
          .container {
            display: flex;
            padding: 24px;
            gap: 24px;
            justify-content: center;
          }
          .container.overlay-mode { position: relative; }
          .container.overlay-mode .panel:last-child {
            position: absolute;
            top: 24px;
            left: 50%;
            transform: translateX(-50%);
          }
          .panel {
            background: #1a1a2e;
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid #2a2a4a;
          }
          .panel-header {
            padding: 12px 16px;
            background: #0f0f14;
            font-size: 13px;
            font-weight: 500;
            color: #4ecca3;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .panel-header .size { color: #808080; font-weight: normal; }
          .panel-content {
            padding: 16px;
            background: #fff;
            overflow: auto;
            max-height: calc(100vh - 180px);
          }
          #original-img {
            width: #{width}px;
            height: auto;
            display: block;
          }
          #generated-root {
            width: #{width}px;
            min-height: #{height}px;
            background: #fff;
          }
          #{generated_styles}
        </style>
      </head>
      <body>
        <div class="header">
          <h1><span>⬡</span> Figma to HTML - Visual Test</h1>
          <div class="test-name">#{@name}</div>
        </div>
        <div class="controls">
          <div class="control-group">
            <input type="checkbox" id="overlay" onchange="toggleOverlay()">
            <label for="overlay">Overlay mode</label>
          </div>
          <div class="control-group">
            <label>Opacity:</label>
            <input type="range" id="opacity" min="0" max="100" value="50" oninput="updateOpacity()">
          </div>
          <div class="control-group">
            <label>Background:</label>
            <button class="btn" onclick="setBg('white')">White</button>
            <button class="btn" onclick="setBg('#1a1a2e')">Dark</button>
            <button class="btn" onclick="setBg('#f0f0f0')">Gray</button>
          </div>
        </div>
        <div class="container" id="container">
          <div class="panel">
            <div class="panel-header">
              <span>Original (Figma Export)</span>
              <span class="size">#{width}×#{height}</span>
            </div>
            <div class="panel-content" id="original-content">
              <img id="original-img" src="#{original_url}" alt="Original">
            </div>
          </div>
          <div class="panel" id="generated-panel">
            <div class="panel-header">
              <span>Generated (HTML)</span>
              <span class="size">#{width}×#{height}</span>
            </div>
            <div class="panel-content" id="generated-content">
              <div id="generated-root">
                #{result[:html]}
              </div>
            </div>
          </div>
        </div>
        <script>
          function toggleOverlay() {
            var overlay = document.getElementById('overlay').checked;
            document.getElementById('container').classList.toggle('overlay-mode', overlay);
            updateOpacity();
          }
          function updateOpacity() {
            var opacity = document.getElementById('opacity').value / 100;
            document.getElementById('generated-panel').style.opacity = 
              document.getElementById('overlay').checked ? opacity : 1;
          }
          function setBg(color) {
            document.getElementById('original-content').style.background = color;
            document.getElementById('generated-content').style.background = color;
          }
        </script>
      </body>
      </html>
    HTML
  end
end
