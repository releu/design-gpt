class FigmaFileConvertJob < ApplicationJob
  queue_as :default

  def perform(figma_file_id)
    ff = FigmaFile.find(figma_file_id)

    ff.update!(status: "converting")
    ff.update_progress(step: "converting", step_number: 3, total_steps: 4, message: "Generating React code...")

    Figma::ReactFactory.new(ff).generate_all

    ff.reload
    sets_with_code = ff.component_sets.joins(:variants).where.not(component_variants: { react_code: [nil, ""] }).distinct.count
    components_with_code = ff.components.where.not(react_code: [nil, ""]).count
    ff.update_progress(step: "converting", step_number: 3, total_steps: 4,
      message: "Complete - #{sets_with_code} component sets, #{components_with_code} standalone components with React code")

    ff.update!(status: "ready", progress: ff.progress.merge("completed_at" => Time.current.iso8601))
    VisualDiffJob.perform_later(ff.id)

    maybe_finalize_design_system(ff)
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
    still_pending = siblings.where(status: %w[pending importing converting comparing])
    return if still_pending.exists?

    if siblings.where(status: "error").exists?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "One or more files failed"))
    else
      ds.update!(status: "ready", progress: ds.progress.merge("completed_at" => Time.current.iso8601))
    end

    # Scale figma_worker back to cheapest size
    HerokuScaler.scale_figma_worker(HerokuScaler::DEFAULT_SIZE)
  end
end
