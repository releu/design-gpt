namespace :pipeline do
  desc "Full pipeline check: sync all design systems, cache Figma screenshots, run pixel diff, populate reviews"
  task full_check: :environment do
    # 1. Find all unique design systems
    design_systems = DesignSystem.where(status: "ready").distinct
    puts "Found #{design_systems.count} design systems"

    design_systems.each do |ds|
      puts "\n#{"=" * 60}"
      puts "Design System: #{ds.name} (id=#{ds.id})"
      puts "=" * 60

      # 2. Sync each figma file
      ds.current_figma_files.each do |ff|
        puts "\n  Syncing: #{ff.figma_file_name} (#{ff.figma_file_key})..."
        ff.sync_with_figma
        puts "  Done — #{ff.component_sets.count} component sets"
      end

      # 3. Cache Figma screenshots
      puts "\n  Caching Figma screenshots..."
      grind = PipelineGrind.new(ds.name)
      grind.cache_figma_screenshots

      # 4. Run quick comparison (10 variants per CS, no AI)
      puts "\n  Running pixel diff..."
      results = grind.quick_test
      next unless results&.any?

      # 5. Populate PipelineReview records
      by_cs = results.group_by { |r| r[:cs] }
      count = 0

      by_cs.each do |cs_name, variants|
        cs = ds.current_figma_files.flat_map { |ff| ff.component_sets.to_a }.find { |c| c.name == cs_name }
        next unless cs

        scores = variants.map { |v| v[:match] }
        variant_scores = variants.map { |v| { name: v[:variant], match: v[:match], status: v[:status] } }

        review = PipelineReview.find_or_initialize_by(component_set: cs)
        review.assign_attributes(
          best_match_percent: scores.max,
          avg_match_percent: (scores.sum / scores.size).round(2),
          variant_scores: variant_scores,
          status: review.new_record? ? "pending" : review.status
        )
        review.save!
        count += 1
      end

      puts "  Populated #{count} reviews"
    end

    # 6. Print summary
    puts "\n#{"=" * 60}"
    puts "SUMMARY"
    puts "=" * 60
    total = PipelineReview.count
    approved = PipelineReview.where(status: "approved").count
    need_fix = PipelineReview.where(status: "need_fix").count
    pending = PipelineReview.where(status: "pending").count
    avg = PipelineReview.average(:avg_match_percent)&.round(1)
    puts "Total: #{total} | Approved: #{approved} | Need fix: #{need_fix} | Pending: #{pending}"
    puts "Average match: #{avg}%"
    puts "\nOpen http://localhost:3000/admin/figma2react to review"
  end
end
