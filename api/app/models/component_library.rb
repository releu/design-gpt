class ComponentLibrary < ApplicationRecord
  belongs_to :user
  has_many :components, dependent: :destroy
  has_many :component_sets, dependent: :destroy
  has_many :design_component_libraries, dependent: :destroy
  has_many :designs, through: :design_component_libraries
  has_many :design_system_libraries, dependent: :destroy
  has_many :design_systems, through: :design_system_libraries

  validates :figma_url, presence: true

  before_validation :extract_figma_file_key, if: -> { figma_url_changed? }

  # Status flow: pending → discovering → importing → converting → comparing → ready / error
  STATUSES = %w[pending discovering importing converting comparing ready error].freeze
  validates :status, inclusion: { in: STATUSES }

  def figma_url_for_node(node_id)
    return nil unless figma_file_key && node_id
    encoded_node_id = node_id.tr(":", "-")
    "https://www.figma.com/design/#{figma_file_key}?node-id=#{encoded_node_id}"
  end

  def sync_with_figma
    # Prevent concurrent syncs — skip if already in progress
    return if %w[importing converting comparing].include?(status)

    # In E2E test mode, skip actual Figma import for seed data (fake file keys)
    # to avoid corrupting test data while parallel tests are running
    if figma_file_key&.start_with?("e2e") && Rails.env.test?
      update!(status: "ready")
      return
    end

    puts "[ComponentLibrary#sync_with_figma] Starting sync for ComponentLibrary##{id}"
    update_progress(step: "importing", step_number: 1, total_steps: 4, message: "Importing from Figma...")

    # 1. Import component structure from Figma (raw JSON, no detaching)
    update!(status: "importing")
    Figma::Importer.new(self).import
    reload
    update_progress(step: "importing", step_number: 1, total_steps: 4,
      message: "Complete - #{component_sets.count} component sets, #{components.count} standalone components")

    # 2. Extract and cache SVG assets for icons
    update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Extracting SVG assets...")
    Figma::AssetExtractor.new(self).extract_all
    update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Complete")

    # 3. Generate React code (uses cached SVGs for inline icons)
    update!(status: "converting")
    update_progress(step: "converting", step_number: 3, total_steps: 4, message: "Generating React code...")
    Figma::ReactFactory.new(self).generate_all
    reload
    sets_with_code = component_sets.joins(:variants).where.not(component_variants: { react_code: [nil, ""] }).distinct.count
    components_with_code = components.where.not(react_code: [nil, ""]).count
    update_progress(step: "converting", step_number: 3, total_steps: 4,
      message: "Complete - #{sets_with_code} component sets, #{components_with_code} standalone components with React code")

    # 4. Visual diff runs in background after sync completes
    update!(status: "ready", progress: progress.merge("completed_at" => Time.current.iso8601))
    VisualDiffJob.perform_later(id)
    puts "[ComponentLibrary#sync_with_figma] Sync complete!"
  rescue => e
    update!(status: "error", progress: progress.merge("error" => e.message))
    raise
  end

  def sync_async
    # Skip if actively syncing — avoid duplicate concurrent imports
    return if %w[importing converting comparing].include?(status)

    update!(status: "pending", progress: { "started_at" => Time.current.iso8601 })
    ComponentLibrarySyncJob.perform_later(id)
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
    puts "[ComponentLibrary#sync_with_figma] Step #{step_number}/#{total_steps}: #{message}"
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
    puts "  Total Variants: #{ComponentVariant.joins(:component_set).where(component_sets: { component_library_id: id }).count}"
    puts "  Standalone Components: #{components.count}"

    nil
  end

  def run_visual_diff
    # Compare standalone components that have React code
    diffable_components = components.where.not(react_code_compiled: [nil, ""])
    diffable_components.each do |comp|
      next if comp.vector?
      Figma::VisualDiff.compare_component(comp)
    rescue => e
      Rails.logger.warn("[VisualDiff] Skipping component #{comp.name}: #{e.message}")
    end

    # Compare component sets (via default variant)
    component_sets.includes(:variants).each do |cs|
      next if cs.vector?
      variant = cs.default_variant
      next unless variant&.react_code_compiled.present?
      Figma::VisualDiff.compare_component_set(cs)
    rescue => e
      Rails.logger.warn("[VisualDiff] Skipping component set #{cs.name}: #{e.message}")
    end
  end

  private

  def extract_figma_file_key
    return unless figma_url.present?

    match = figma_url.match(%r{figma\.com/(?:file|design)/([a-zA-Z0-9]+)})
    self.figma_file_key = match&.[](1)
  end
end
