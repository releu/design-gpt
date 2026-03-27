namespace :pipeline do
  desc "Fix loop: pick next failed component, GPT-4o diagnose, print issues for Claude Code to fix"
  task :fix_next, [:component_name] => :environment do |_t, args|
    # Pick component: explicit name, or next need_fix, or worst pending
    # Skip components with validation warnings or unresolved pink placeholders
    clean_ids = ComponentSet.without_warnings.select(:id)
    pink_cs_ids = ComponentVariant.where(component_set_id: clean_ids)
      .where("react_code_compiled LIKE '%FF69B4%'")
      .select(:component_set_id).distinct
    fixable_ids = ComponentSet.without_warnings.where.not(id: pink_cs_ids).select(:id)

    review = if args[:component_name]
      cs = ComponentSet.find_by!(name: args[:component_name])
      PipelineReview.find_by!(component_set: cs)
    else
      PipelineReview.where(component_set_id: fixable_ids).need_fix.by_match.first ||
        PipelineReview.where(component_set_id: fixable_ids, status: "pending").by_match.first
    end

    unless review
      puts "No components to fix. All done!"
      next
    end

    cs = review.component_set
    puts "=" * 60
    puts "FIXING: #{cs.name}"
    puts "Status: #{review.status} | Best: #{review.best_match_percent}% | Avg: #{review.avg_match_percent}%"
    puts "Figma: #{cs.figma_url}"
    puts "=" * 60

    # Show existing warnings
    warnings = cs.validation_warnings || []
    if warnings.any?
      puts "\nWARNINGS (#{warnings.size}):"
      warnings.each { |w| puts "  ! #{w}" }
    end

    # Regenerate + screenshot + diff
    grind = PipelineGrind.new
    grind.instance_variable_set(:@skip_ai, false) # enable GPT-4o
    results = grind.quick_test(cs.name)

    unless results&.any?
      puts "\nNo results — component may have no compiled variants."
      next
    end

    # Collect GPT-4o issues
    all_issues = []
    results.each do |r|
      if r[:ai_issues]&.any?
        all_issues << { variant: r[:variant], match: r[:match], issues: r[:ai_issues] }
      end
    end

    # Update review
    scores = results.map { |r| r[:match] }
    variant_scores = results.map { |r| { name: r[:variant], match: r[:match], status: r[:status] } }
    review.update!(
      best_match_percent: scores.max,
      avg_match_percent: (scores.sum / scores.size).round(2),
      variant_scores: variant_scores,
      ai_analysis: all_issues
    )

    pass = results.count { |r| r[:status] == "PASS" }
    puts "\n" + "=" * 60
    puts "RESULT: #{pass}/#{results.size} pass | Avg: #{review.avg_match_percent}%"
    puts "=" * 60

    if all_issues.empty?
      puts "\nGPT-4o: No issues found. Component looks good!"
      review.update!(status: "ready_to_review")
    else
      puts "\nGPT-4o ISSUES TO FIX:"
      all_issues.each do |vi|
        puts "\n  #{vi[:variant]} (#{vi[:match]}%):"
        vi[:issues].each { |i| puts "    - #{i}" }
      end
      review.update!(status: "need_fix") if review.status == "pending"
    end

    puts "\nComponent: #{cs.name}"
    puts "Files to check:"
    puts "  - app/services/figma/style_extractor.rb"
    puts "  - app/services/figma/resolver.rb"
    puts "  - app/services/figma/emitter.rb"
  end

  desc "Verify fix: re-run comparison + GPT-4o for a component, check if issues are resolved"
  task :verify_fix, [:component_name] => :environment do |_t, args|
    unless args[:component_name]
      puts "Usage: rake pipeline:verify_fix[ComponentName]"
      next
    end

    cs = ComponentSet.find_by!(name: args[:component_name])
    review = PipelineReview.find_by!(component_set: cs)

    puts "Verifying: #{cs.name}..."

    grind = PipelineGrind.new
    grind.instance_variable_set(:@skip_ai, false)
    results = grind.quick_test(cs.name)

    unless results&.any?
      puts "No results."
      next
    end

    scores = results.map { |r| r[:match] }
    pass = results.count { |r| r[:status] == "PASS" }
    avg = (scores.sum / scores.size).round(2)

    all_issues = []
    results.each do |r|
      if r[:ai_issues]&.any?
        all_issues << { variant: r[:variant], match: r[:match], issues: r[:ai_issues] }
      end
    end

    variant_scores = results.map { |r| { name: r[:variant], match: r[:match], status: r[:status] } }
    review.update!(
      best_match_percent: scores.max,
      avg_match_percent: avg,
      variant_scores: variant_scores,
      ai_analysis: all_issues
    )

    puts "\n#{pass}/#{results.size} pass | Avg: #{avg}%"

    if all_issues.empty?
      puts "GPT-4o: All clear! No visual issues."
      review.update!(status: "ready_to_review")
      puts "\nRun `rake pipeline:regression` to check nothing else broke."
    else
      puts "\nSTILL HAS ISSUES:"
      all_issues.each do |vi|
        puts "\n  #{vi[:variant]} (#{vi[:match]}%):"
        vi[:issues].each { |i| puts "    - #{i}" }
      end
      puts "\nFix and run `rake pipeline:verify_fix[#{cs.name}]` again."
    end
  end

  desc "Regression: quick diff on all components, flag any that got worse"
  task regression: :environment do
    puts "Running regression check..."

    grind = PipelineGrind.new
    grind.instance_variable_set(:@skip_ai, true)
    results = grind.quick_test

    unless results&.any?
      puts "No results."
      next
    end

    # Compare against stored scores (skip components with warnings)
    by_cs = results.group_by { |r| r[:cs] }
    regressions = []

    by_cs.each do |cs_name, variants|
      cs = ComponentSet.find_by(name: cs_name)
      next unless cs
      next if cs.has_warnings?

      review = PipelineReview.find_by(component_set: cs)
      next unless review

      old_avg = review.avg_match_percent || 0
      new_scores = variants.map { |v| v[:match] }
      new_avg = (new_scores.sum / new_scores.size).round(2)

      if new_avg < old_avg - 1.0 # more than 1% worse
        regressions << { name: cs_name, old: old_avg, new: new_avg, delta: (new_avg - old_avg).round(2) }
      end

      # Update scores
      variant_scores = variants.map { |v| { name: v[:variant], match: v[:match], status: v[:status] } }
      review.update!(
        best_match_percent: new_scores.max,
        avg_match_percent: new_avg,
        variant_scores: variant_scores
      )
    end

    pass = results.count { |r| r[:status] == "PASS" }
    avg = (results.sum { |r| r[:match] } / results.size).round(1)
    puts "\nOverall: #{pass}/#{results.size} pass | Avg: #{avg}%"

    if regressions.any?
      puts "\nREGRESSIONS (got worse by >1%):"
      regressions.sort_by { |r| r[:delta] }.each do |r|
        puts "  #{r[:name]}: #{r[:old]}% -> #{r[:new]}% (#{r[:delta]}%)"
      end
    else
      puts "\nNo regressions detected."
    end
  end
end
