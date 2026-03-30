class FigmaFile < ApplicationRecord
  belongs_to :user
  belongs_to :design_system, optional: true
  has_many :components, dependent: :destroy
  has_many :component_sets, dependent: :destroy

  validates :figma_url, presence: true

  before_validation :extract_figma_file_key, if: -> { figma_url_changed? }

  # Status flow: pending → importing → converting → comparing → ready / error
  STATUSES = %w[pending discovering importing converting comparing ready error].freeze
  validates :status, inclusion: { in: STATUSES }

  def figma_url_for_node(node_id)
    return nil unless figma_file_key && node_id
    encoded_node_id = node_id.tr(":", "-")
    "https://www.figma.com/design/#{figma_file_key}?node-id=#{encoded_node_id}"
  end

  def sync_with_figma
    # Prevent concurrent syncs
    return if %w[importing converting comparing].include?(status)

    if figma_file_key&.start_with?("e2e") && Rails.env.test?
      update!(status: "ready")
      return
    end

    puts "[FigmaFile#sync_with_figma] Starting sync for FigmaFile##{id}"
    update_progress(step: "importing", step_number: 1, total_steps: 4, message: "Importing from Figma...")

    # 1. Import component structure from Figma
    update!(status: "importing")
    Figma::Importer.new(self).import
    reload
    update_progress(step: "importing", step_number: 1, total_steps: 4,
      message: "Complete - #{component_sets.count} component sets, #{components.count} standalone components")

    # 2. Extract and cache SVG assets
    update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Extracting SVG assets...")
    Figma::AssetExtractor.new(self).extract_all
    update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Complete")

    # 3. Generate React code
    update!(status: "converting")
    update_progress(step: "converting", step_number: 3, total_steps: 4, message: "Generating React code...")
    Figma::ReactFactory.new(self).generate_all
    reload
    sets_with_code = component_sets.joins(:variants).where.not(component_variants: { react_code: [nil, ""] }).distinct.count
    components_with_code = components.where.not(react_code: [nil, ""]).count
    update_progress(step: "converting", step_number: 3, total_steps: 4,
      message: "Complete - #{sets_with_code} component sets, #{components_with_code} standalone components with React code")

    update!(status: "ready", progress: progress.merge("completed_at" => Time.current.iso8601))
    puts "[FigmaFile#sync_with_figma] Sync complete!"
  rescue => e
    update!(status: "error", progress: progress.merge("error" => e.message))
    raise
  end

  def update_progress(step:, step_number:, total_steps:, message:)
    new_progress = progress.merge(
      "step" => step,
      "step_number" => step_number,
      "total_steps" => total_steps,
      "message" => message,
      "updated_at" => Time.current.iso8601
    )
    update!(progress: new_progress)
    puts "[FigmaFile#sync_with_figma] Step #{step_number}/#{total_steps}: #{message}"
  end

  def run_visual_diff
    diffable_components = components.where.not(react_code_compiled: [nil, ""])
    diffable_components.each do |comp|
      next if comp.vector?
      Figma::VisualDiff.compare_component(comp)
    rescue => e
      Rails.logger.warn("[VisualDiff] Skipping component #{comp.name}: #{e.message}")
    end

    component_sets.includes(:variants).each do |cs|
      next if cs.vector?
      variant = cs.default_variant
      next unless variant&.react_code_compiled.present?
      Figma::VisualDiff.compare_component_set(cs)
    rescue => e
      Rails.logger.warn("[VisualDiff] Skipping component set #{cs.name}: #{e.message}")
    end
  end

  def print_tree
    component_sets.includes(:variants).group_by(&:figma_file_name).each do |file_name, sets|
      puts "📁 #{file_name || 'Unknown'}"

      sets.each do |set|
        vector_marker = set.vector? ? "🎨" : "📦"
        puts "  #{vector_marker} #{set.name} (#{set.variants.count} variants)"

        set.variants.first(3).each do |variant|
          default_marker = variant.is_default ? " ★" : ""
          puts "    ├─ #{variant.name}#{default_marker}"
        end

        if set.variants.count > 3
          puts "    └─ ... and #{set.variants.count - 3} more"
        end
      end

      puts ""
    end

    standalone = components.group_by(&:figma_file_name)
    if standalone.any?
      standalone.each do |file_name, comps|
        puts "📁 #{file_name || 'Unknown'} (standalone)"

        comps.each do |c|
          vector_marker = c.vector? ? "🎨" : "📄"
          puts "  #{vector_marker} #{c.name}"
          puts "     └─ #{c.figma_url}"
        end

        puts ""
      end
    end

    puts "─" * 40
    puts "Summary:"
    puts "  Component Sets: #{component_sets.count}"
    puts "  Total Variants: #{ComponentVariant.joins(:component_set).where(component_sets: { figma_file_id: id }).count}"
    puts "  Standalone Components: #{components.count}"

    nil
  end

  private

  def extract_figma_file_key
    return unless figma_url.present?

    match = figma_url.match(%r{figma\.com/(?:file|design)/([a-zA-Z0-9]+)})
    self.figma_file_key = match&.[](1)
  end
end
