require "fileutils"

class PipelineReviewService
  OUTPUT_DIR = Rails.root.join("tmp", "pipeline_grind")

  def initialize(design_system = nil)
    @ds = design_system || DesignSystem.first
  end

  # Run comparison for all component sets, populate PipelineReview records
  def run_all
    grind = PipelineGrind.new(@ds.name)
    results = grind.quick_test

    return [] unless results&.any?

    # Group results by component set name
    by_cs = results.group_by { |r| r[:cs] }

    by_cs.each do |cs_name, variants|
      cs = ComponentSet.find_by(name: cs_name)
      next unless cs

      scores = variants.map { |v| v[:match] }
      best = scores.max
      avg = (scores.sum / scores.size).round(2)

      variant_scores = variants.map do |v|
        { name: v[:variant], match: v[:match], status: v[:status] }
      end

      review = PipelineReview.find_or_initialize_by(component_set: cs)
      review.assign_attributes(
        best_match_percent: best,
        avg_match_percent: avg,
        variant_scores: variant_scores,
        status: review.new_record? ? "pending" : review.status
      )
      review.save!
    end
  end

  # Run comparison for a single component set
  def run_one(component_set)
    grind = PipelineGrind.new(@ds.name)
    results = grind.quick_test(component_set.name)
    return unless results&.any?

    scores = results.map { |r| r[:match] }
    variant_scores = results.map do |r|
      { name: r[:variant], match: r[:match], status: r[:status] }
    end

    review = PipelineReview.find_or_initialize_by(component_set: component_set)
    review.assign_attributes(
      best_match_percent: scores.max,
      avg_match_percent: (scores.sum / scores.size).round(2),
      variant_scores: variant_scores
    )
    review.save!
    review
  end

  # Get comparison image path for a variant
  def self.comparison_path(component_set_name, variant_name)
    safe_cs = component_set_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    safe_v = variant_name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
    OUTPUT_DIR.join("components", safe_cs, safe_v, "comparison.png")
  end

  def self.figma_screenshot_path(component_set_name, variant_name)
    safe_cs = component_set_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    safe_v = variant_name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
    OUTPUT_DIR.join("components", safe_cs, safe_v, "figma.png")
  end

  def self.react_screenshot_path(component_set_name, variant_name)
    safe_cs = component_set_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    safe_v = variant_name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
    OUTPUT_DIR.join("components", safe_cs, safe_v, "react.png")
  end

  def self.diff_screenshot_path(component_set_name, variant_name)
    safe_cs = component_set_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    safe_v = variant_name.gsub(/[^a-zA-Z0-9=,_-]/, "_")
    OUTPUT_DIR.join("components", safe_cs, safe_v, "diff.png")
  end
end
