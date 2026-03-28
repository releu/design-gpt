module PipelineAutofix
  PIPELINE_FILES = %w[
    api/app/services/figma/style_extractor.rb
    api/app/services/figma/resolver.rb
    api/app/services/figma/emitter.rb
  ].freeze

  def self.fixable_component_ids
    clean_ids = ComponentSet.without_warnings.select(:id)
    pink_cs_ids = ComponentVariant.where(component_set_id: clean_ids)
      .where("react_code_compiled LIKE '%FF69B4%'")
      .select(:component_set_id).distinct
    ComponentSet.without_warnings.where.not(id: pink_cs_ids).select(:id)
  end

  def self.pick_all(threshold: 95.0)
    fixable_ids = fixable_component_ids
    PipelineReview.where(component_set_id: fixable_ids)
      .where(status: %w[need_fix pending])
      .where(ai_resolution: [nil, ""])
      .where("avg_match_percent < ? OR avg_match_percent IS NULL", threshold)
      .by_match
      .map { |r| [r, r.component_set] }
  end

  def self.build_prompt(cs, results)
    figma_context = cs.variants.order(:id).limit(3).map do |cv|
      data = cv.figma_json
      children_info = (data["children"] || []).map.with_index do |c, i|
        bb = c["absoluteBoundingBox"] || {}
        fills = (c["fills"] || []).select { |f| f["visible"] != false }
        fill_str = fills.map { |f|
          color = f["color"]
          next unless color
          r = (color["r"] * 255).round; g = (color["g"] * 255).round; b = (color["b"] * 255).round
          a = (color["a"] || 1) * (f["opacity"] || 1)
          a < 0.99 ? "rgba(#{r},#{g},#{b},#{a.round(2)})" : "#%02x%02x%02x" % [r, g, b]
        }.compact.join(", ")
        style = c["style"]
        font_str = style ? "font=#{style['fontFamily']} #{style['fontSize']}px w#{style['fontWeight']}" : ""
        line = "  Child #{i}: #{c['name']} (#{c['type']}) #{bb['width']}x#{bb['height']}"
        line += " fills=[#{fill_str}]" if fill_str.present?
        line += " #{font_str}" if font_str.present?
        line += " visible=false" if c["visible"] == false
        line += " layoutSizingH=#{c['layoutSizingHorizontal']}" if c["layoutSizingHorizontal"]
        line += " layoutGrow=#{c['layoutGrow']}" if c["layoutGrow"]&.positive?
        line
      end.join("\n")
      <<~INFO
        Variant: #{cv.name}
        Root: layout=#{data['layoutMode']} gap=#{data['itemSpacing']} padding=#{[data['paddingLeft'], data['paddingTop'], data['paddingRight'], data['paddingBottom']].compact.inspect}
        Root size: #{data.dig('absoluteBoundingBox', 'width')}x#{data.dig('absoluteBoundingBox', 'height')}
        Root fills: #{(data['fills'] || []).select { |f| f['visible'] != false }.any? ? 'yes' : 'none'}
        Root effects: #{(data['effects'] || []).select { |e| e['visible'] != false }.any? ? 'yes' : 'none'}
        Root cornerRadius: #{data['cornerRadius'] || 'none'}
        #{children_info}
      INFO
    end.join("\n")

    issues_text = results.filter_map do |r|
      issues = r[:ai_issues] || []
      next if issues.empty?
      "#{r[:variant]} (#{r[:match]}%):\n" + issues.map { |i| "  - #{i}" }.join("\n")
    end.join("\n\n")

    safe_cs = cs.name.gsub(/^\./, "_").gsub(/[^a-zA-Z0-9_-]/, "_")
    comparison_dir = Rails.root.join("tmp/pipeline_grind/components/#{safe_cs}")
    comparison_paths = comparison_dir.exist? ? Dir.glob(comparison_dir.join("*/comparison.png")).sort.first(5) : []
    scores_text = results.map { |r| "#{r[:variant]}: #{r[:match]}% #{r[:status]}" }.join("\n")

    <<~PROMPT
      Fix the Figma-to-React pipeline for component "#{cs.name}" to improve visual match scores.

      CURRENT SCORES (pass threshold is 95%):
      #{scores_text}

      GPT-4o IDENTIFIED ISSUES:
      #{issues_text.presence || "No specific issues identified."}

      FIGMA STRUCTURE (first #{[cs.variants.count, 3].min} variants):
      #{figma_context}

      COMPARISON IMAGES (left=Figma, middle=React, right=diff):
      #{comparison_paths.map(&:to_s).join("\n")}

      FILES YOU MAY EDIT:
      - api/app/services/figma/style_extractor.rb  (CSS extraction from Figma JSON)
      - api/app/services/figma/resolver.rb          (Figma node → IR tree)
      - api/app/services/figma/emitter.rb           (IR tree → React/CSS)

      WORKFLOW:
      1. Read the comparison images to see exactly what's wrong
      2. Read the compiled React code: bundle exec rails runner "cs = ComponentSet.find_by!(name: '#{cs.name}'); cs.variants.first.react_code_compiled.tap { |c| puts c }"
      3. Read the Figma JSON for specific details: bundle exec rails runner "cs = ComponentSet.find_by!(name: '#{cs.name}'); puts JSON.pretty_generate(cs.variants.first.figma_json)"
      4. Identify the root cause in style_extractor.rb, resolver.rb, or emitter.rb
      5. Make targeted code changes
      6. Verify: bundle exec rake "pipeline:verify_fix[#{cs.name}]"
      7. Read updated comparison images to check improvement
      8. Repeat steps 4-7 until GPT-4o issues are resolved or remaining issues are only font rendering / shadow rendering / sub-pixel differences that can't be fixed in CSS
      9. Do NOT run pipeline:regression — that happens externally after all fixes.

      IMPORTANT RULES:
      - Do NOT use Claude vision for comparing screenshots. Only GPT-4o via verify_fix does visual inspection.
      - Do NOT make broad changes that could regress other components. Keep fixes targeted.
      - If the issue is about a library sub-component (Button, Avatar, etc.) not rendering correctly, that's not fixable — skip it.

      FINAL OUTPUT — your very last line MUST be exactly one of (the orchestrator parses it):
        RESOLUTION: fixed
        RESOLUTION: not-fixable — <reason>
        RESOLUTION: partial — <reason>
    PROMPT
  end

  def self.run_claude(prompt, workdir:, &block)
    cmd = [
      "claude", "-p",
      "--allowedTools", "Bash Read Edit Grep Glob",
      "--model", "sonnet",
      "--permission-mode", "acceptEdits"
    ]
    IO.popen(cmd, "r+", chdir: workdir, err: [:child, :out]) do |io|
      io.write(prompt)
      io.close_write
      io.each_line { |line| block&.call(line) }
    end
  end

  def self.parse_resolution(log_path)
    return nil unless File.exist?(log_path)
    lines = File.readlines(log_path).map(&:strip)
    resolution_line = lines.reverse.find { |l| l.start_with?("RESOLUTION:") }
    return nil unless resolution_line
    resolution_line.sub("RESOLUTION:", "").strip
  end
end

namespace :pipeline do
  desc "Auto-fix: pick one <95% component and launch Claude Code to fix it"
  task :autofix, [:component_name] => :environment do |_t, args|
    fixable_ids = PipelineAutofix.fixable_component_ids
    review = if args[:component_name]
      PipelineReview.find_by!(component_set: ComponentSet.find_by!(name: args[:component_name]))
    else
      PipelineReview.where(component_set_id: fixable_ids, ai_resolution: [nil, ""])
        .where(status: %w[need_fix pending]).by_match.first
    end
    abort "No components to fix!" unless review

    cs = review.component_set
    puts "AUTOFIX: #{cs.name} (#{review.avg_match_percent}%)"

    grind = PipelineGrind.new
    grind.instance_variable_set(:@skip_ai, false)
    results = grind.quick_test(cs.name)
    abort "No results." unless results&.any?

    prompt = PipelineAutofix.build_prompt(cs, results)
    PipelineAutofix.run_claude(prompt, workdir: Rails.root.to_s) { |l| puts l }
  end

  desc "Fix ALL components below threshold: diagnose → parallel fix (N workers) → merge → regression"
  task :autofix_all, [:workers, :threshold] => :environment do |_t, args|
    workers   = (args[:workers] || 5).to_i
    threshold = (args[:threshold] || 95.0).to_f
    repo_root = Rails.root.join("..").realpath
    api_dir   = Rails.root.realpath

    # ══════════════════════════════════════════════════════════
    # Phase 1: Baseline — diagnose all components below threshold
    # ══════════════════════════════════════════════════════════
    all_pairs = PipelineAutofix.pick_all(threshold: threshold)
    abort "No components below #{threshold}%. Done!" if all_pairs.empty?

    puts "=" * 60
    puts "AUTOFIX ALL: #{all_pairs.size} components below #{threshold}% with #{workers} workers"
    all_pairs.each { |r, cs| puts "  #{cs.name} — #{r.avg_match_percent || '?'}%" }
    puts "=" * 60

    puts "\nPhase 1: Diagnosing all #{all_pairs.size} components..."
    grind = PipelineGrind.new
    grind.instance_variable_set(:@skip_ai, false)

    queue = Queue.new
    all_pairs.each do |review, cs|
      puts "  Diagnosing: #{cs.name}..."
      results = grind.quick_test(cs.name)
      unless results&.any?
        puts "    skip — no results"
        review.update!(ai_resolution: "not-fixable — no compiled variants")
        next
      end
      prompt = PipelineAutofix.build_prompt(cs, results)
      queue << { review: review, cs: cs, prompt: prompt }
    end

    total = queue.size
    puts "\n#{total} components ready for fixing."
    abort "Nothing to fix." if total == 0

    # ══════════════════════════════════════════════════════════
    # Phase 2: Fix — N workers pulling from queue
    # ══════════════════════════════════════════════════════════
    puts "\nPhase 2: Launching #{workers} parallel workers..."
    completed = Queue.new
    mutex = Mutex.new
    counter = 0

    threads = workers.times.map do |worker_id|
      Thread.new do
        loop do
          job = begin; queue.pop(true); rescue ThreadError; nil; end
          break unless job

          n = mutex.synchronize { counter += 1; counter }
          cs_name = job[:cs].name
          slug = cs_name.gsub(/[^a-zA-Z0-9_-]/, "_").downcase
          branch = "autofix/#{slug}_#{Process.pid}_#{worker_id}"
          wt_path = repo_root.join("tmp/autofix_wt_#{worker_id}")
          log_path = api_dir.join("tmp/autofix_log_w#{worker_id}.txt")

          mutex.synchronize do
            puts "  [w#{worker_id}] (#{n}/#{total}) Starting: #{cs_name}"
          end

          # Setup worktree
          if wt_path.exist?
            system("git", "-C", repo_root.to_s, "worktree", "remove", "--force", wt_path.to_s,
                   out: File::NULL, err: File::NULL)
            FileUtils.rm_rf(wt_path) if wt_path.exist?
          end
          system("git", "-C", repo_root.to_s, "branch", "-D", branch,
                 out: File::NULL, err: File::NULL) # clean stale branch
          system("git", "-C", repo_root.to_s, "worktree", "add", "-b", branch,
                 wt_path.to_s, "HEAD", out: File::NULL, err: File::NULL)

          # Run Claude
          File.open(log_path, "w") do |log|
            log.puts "AUTOFIX: #{cs_name}  worker=#{worker_id}  branch=#{branch}"
            log.flush
            PipelineAutofix.run_claude(job[:prompt], workdir: wt_path.join("api").to_s) do |line|
              log.puts line
              log.flush
            end
            log.puts "\n[DONE]"
          end

          # Collect result
          resolution = PipelineAutofix.parse_resolution(log_path)
          diff = `git -C #{wt_path} diff HEAD -- api/app/services/figma/`.strip

          patch_path = nil
          if diff.present?
            patch_path = api_dir.join("tmp/autofix_patch_#{slug}.patch")
            File.write(patch_path, diff)
          end

          # Save resolution to DB
          job[:review].update!(ai_resolution: resolution) if resolution

          completed << {
            cs_name: cs_name, review: job[:review], resolution: resolution,
            patch: patch_path, wt_path: wt_path, branch: branch, log: log_path
          }

          added   = diff.present? ? diff.lines.count { |l| l.start_with?("+") && !l.start_with?("+++") } : 0
          removed = diff.present? ? diff.lines.count { |l| l.start_with?("-") && !l.start_with?("---") } : 0
          status  = patch_path ? "+#{added}/-#{removed}" : "no changes"

          mutex.synchronize do
            puts "  [w#{worker_id}] (#{n}/#{total}) Done: #{cs_name} → #{resolution || 'no resolution'} (#{status})"
          end

          # Cleanup worktree (keep patch)
          system("git", "-C", repo_root.to_s, "worktree", "remove", "--force", wt_path.to_s,
                 out: File::NULL, err: File::NULL)
          system("git", "-C", repo_root.to_s, "branch", "-D", branch,
                 out: File::NULL, err: File::NULL)
        end
      end
    end

    threads.each(&:join)

    # Drain completed queue
    results = []
    loop do
      results << completed.pop(true)
    rescue ThreadError
      break
    end

    patches = results.select { |r| r[:patch] }
    no_changes = results.reject { |r| r[:patch] }

    puts "\n" + "=" * 60
    puts "Phase 2 complete: #{results.size} components processed"
    puts "  With patches: #{patches.size}"
    puts "  No changes:   #{no_changes.size}"
    puts "=" * 60

    if patches.empty?
      puts "\nNo patches to apply. Done."
      next
    end

    # ══════════════════════════════════════════════════════════
    # Phase 3: Merge — apply patches one by one
    # ══════════════════════════════════════════════════════════
    puts "\nPhase 3: Applying #{patches.size} patches..."
    applied = []
    conflicts = []

    patches.each do |p|
      if system("git", "-C", repo_root.to_s, "apply", "--3way", p[:patch].to_s,
                out: File::NULL, err: File::NULL)
        puts "  ✓ #{p[:cs_name]}"
        applied << p
      else
        # Reset partial merge
        system("git", "-C", repo_root.to_s, "checkout", "--",
               *PipelineAutofix::PIPELINE_FILES.map { |f| File.join(repo_root, f) },
               out: File::NULL, err: File::NULL)
        # Re-apply previous clean patches
        applied.each do |prev|
          system("git", "-C", repo_root.to_s, "apply", "--3way", prev[:patch].to_s,
                 out: File::NULL, err: File::NULL)
        end
        puts "  ✗ #{p[:cs_name]} — merge conflict, skipped"
        conflicts << p
      end
    end

    puts "\nApplied: #{applied.size} | Conflicts: #{conflicts.size}"

    if applied.empty?
      puts "No patches applied successfully."
      next
    end

    # ══════════════════════════════════════════════════════════
    # Phase 4: Regression — one full test run
    # ══════════════════════════════════════════════════════════
    puts "\nPhase 4: Running regression check..."
    grind2 = PipelineGrind.new
    grind2.instance_variable_set(:@skip_ai, true)
    all_test_results = grind2.quick_test

    if all_test_results&.any?
      regressions = []
      all_test_results.group_by { |r| r[:cs] }.each do |name, variants|
        cs = ComponentSet.find_by(name: name)
        next unless cs && !cs.has_warnings?
        pr = PipelineReview.find_by(component_set: cs)
        next unless pr
        old_avg = pr.avg_match_percent || 0
        new_avg = (variants.sum { |v| v[:match] } / variants.size).round(2)
        regressions << { name: name, old: old_avg, new: new_avg, delta: (new_avg - old_avg).round(2) } if new_avg < old_avg - 2.0
      end

      pass = all_test_results.count { |r| r[:status] == "PASS" }
      avg = (all_test_results.sum { |r| r[:match] } / all_test_results.size).round(1)
      puts "\nResults: #{pass}/#{all_test_results.size} pass | Avg: #{avg}%"

      if regressions.any?
        puts "\nREGRESSIONS (>2% worse):"
        regressions.each { |r| puts "  #{r[:name]}: #{r[:old]}% → #{r[:new]}% (#{r[:delta]}%)" }
        puts "\nReverting all patches..."
        system("git", "-C", repo_root.to_s, "checkout", "--",
               *PipelineAutofix::PIPELINE_FILES.map { |f| File.join(repo_root, f) })
        puts "Reverted. Patches saved in tmp/autofix_patch_*.patch for manual review."
      else
        puts "\nNo regressions! Updating scores..."
        all_test_results.group_by { |r| r[:cs] }.each do |name, variants|
          cs = ComponentSet.find_by(name: name)
          next unless cs
          pr = PipelineReview.find_by(component_set: cs)
          next unless pr
          scores = variants.map { |v| v[:match] }
          variant_scores = variants.map { |v| { name: v[:variant], match: v[:match], status: v[:status] } }
          pr.update!(best_match_percent: scores.max,
                     avg_match_percent: (scores.sum / scores.size).round(2),
                     variant_scores: variant_scores)
        end
      end
    end

    # ══════════════════════════════════════════════════════════
    # Summary
    # ══════════════════════════════════════════════════════════
    puts "\n" + "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Components processed: #{results.size}"
    puts "Patches applied:      #{applied.size}"
    puts "Merge conflicts:      #{conflicts.size}"
    puts "No changes:           #{no_changes.size}"
    puts "\nResolutions:"
    results.group_by { |r| r[:resolution] || "unknown" }.sort.each do |res, items|
      puts "  #{res}: #{items.size}"
      items.each { |i| puts "    - #{i[:cs_name]}" }
    end
    puts "\nLogs:    tmp/autofix_log_w*.txt"
    puts "Patches: tmp/autofix_patch_*.patch"
  end
end
