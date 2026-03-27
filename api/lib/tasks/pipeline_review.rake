namespace :pipeline do
  desc "Populate pipeline reviews from existing comparison data in tmp/pipeline_grind"
  task populate_reviews: :environment do
    output_dir = Rails.root.join("tmp", "pipeline_grind", "components")
    unless Dir.exist?(output_dir)
      puts "No comparison data found. Run `rake pipeline:quick` first."
      next
    end

    ds = DesignSystem.first
    count = 0

    ds.current_figma_files.each do |ff|
      ff.component_sets.includes(:variants).reject(&:vector?).each do |cs|
        safe_cs = cs.name.gsub(/[^a-zA-Z0-9_-]/, "_")
        cs_dir = output_dir.join(safe_cs)
        next unless Dir.exist?(cs_dir)

        variant_scores = []
        cs.variants.select { |v| v.react_code_compiled.present? }.each do |v|
          variant_label = v.name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
          dir = cs_dir.join(variant_label)
          figma_path = dir.join("figma.png")
          react_path = dir.join("react.png")
          diff_path = dir.join("diff.png")

          next unless File.exist?(figma_path) && File.exist?(react_path) && File.exist?(diff_path)

          # Run pixel diff
          diff_result = Figma::VisualDiff.new(nil, output_dir: dir.to_s)
            .send(:pixel_diff, figma_path.to_s, react_path.to_s, diff_path.to_s)
          match = (100 - diff_result[:diff_percent]).round(2)

          # Build comparison image if missing
          comp_path = dir.join("comparison.png")
          unless File.exist?(comp_path)
            PipelineGrind.new.send(:build_comparison_image, figma_path.to_s, react_path.to_s, diff_path.to_s, dir.to_s)
          end

          variant_scores << { name: v.name, match: match, status: match >= 95.0 ? "PASS" : "FAIL" }
        end

        next if variant_scores.empty?

        scores = variant_scores.map { |v| v[:match] }
        review = PipelineReview.find_or_initialize_by(component_set: cs)
        review.assign_attributes(
          best_match_percent: scores.max,
          avg_match_percent: (scores.sum / scores.size).round(2),
          variant_scores: variant_scores,
          status: review.persisted? ? review.status : "pending"
        )
        review.save!
        count += 1
        puts "  #{review.best_match_percent}% #{cs.name} (#{variant_scores.size} variants)"
      end
    end

    puts "\nPopulated #{count} reviews."
  end

  desc "Run full comparison and populate reviews (regenerate + screenshot + diff)"
  task run_reviews: :environment do
    PipelineReviewService.new.run_all
  end
end
