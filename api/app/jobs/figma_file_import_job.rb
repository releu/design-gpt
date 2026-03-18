class FigmaFileImportJob < ApplicationJob
  queue_as :figma
  limits_concurrency key: ->(_) { "figma_api" }, to: 1

  def perform(figma_file_id)
    ff = FigmaFile.find(figma_file_id)
    ds = ff.design_system

    ff.update!(status: "importing")
    ff.update_progress(step: "importing", step_number: 1, total_steps: 4, message: "Importing from Figma...")

    # 1. Import component structure
    Figma::Importer.new(ff).import
    ff.reload
    ff.update_progress(step: "importing", step_number: 1, total_steps: 4,
      message: "Complete - #{ff.component_sets.count} component sets, #{ff.components.count} standalone components")

    # 2. Extract SVG assets
    ff.update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Extracting SVG assets...")
    Figma::AssetExtractor.new(ff).extract_all
    ff.update_progress(step: "extracting_assets", step_number: 2, total_steps: 4, message: "Complete")

    # Enqueue convert job
    FigmaFileConvertJob.perform_later(ff.id)
  rescue => e
    ff.update!(status: "error", progress: ff.progress.merge("error" => e.message))
    maybe_finalize_design_system(ff)
    raise
  end

  private

  def maybe_finalize_design_system(ff)
    ds = ff.design_system
    return unless ds

    siblings = ds.figma_files.where(version: ff.version)
    return if siblings.where(status: %w[pending importing converting comparing]).where.not(id: ff.id).exists?

    if siblings.where(status: "error").exists?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "One or more files failed"))
      HerokuScaler.scale_down_figma_worker
    end
  end
end
