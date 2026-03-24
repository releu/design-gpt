class FigmaFileImportJob < ApplicationJob
  queue_as :figma
  limits_concurrency key: ->(_) { "figma_api" }, to: 1

  def perform(figma_file_id)
    ff = FigmaFile.find(figma_file_id)

    # Level 1: Skip unchanged files entirely
    if skip_unchanged_file?(ff)
      copy_from_previous_version(ff)
      maybe_finalize_design_system(ff)
      return
    end

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

  def skip_unchanged_file?(ff)
    prev = previous_version_file(ff)
    return false unless prev&.figma_last_modified.present?

    figma = Figma::TokenPool.instance.primary_client
    meta = figma.get("/v1/files/#{ff.figma_file_key}?depth=1")
    current_modified = meta["lastModified"]

    if current_modified == prev.figma_last_modified
      puts "[FigmaFileImportJob] File #{ff.figma_file_key} unchanged (lastModified: #{current_modified}), copying from v#{prev.version}"
      true
    else
      puts "[FigmaFileImportJob] File #{ff.figma_file_key} changed (#{prev.figma_last_modified} → #{current_modified}), full import"
      false
    end
  rescue => e
    puts "[FigmaFileImportJob] Failed to check lastModified for #{ff.figma_file_key}: #{e.message}, proceeding with full import"
    false
  end

  def previous_version_file(ff)
    return nil unless ff.design_system && ff.version > 1

    ff.design_system.figma_files
      .where(figma_file_key: ff.figma_file_key, version: ff.version - 1)
      .first
  end

  def copy_from_previous_version(ff)
    prev = previous_version_file(ff)
    ff.update!(status: "importing", figma_last_modified: prev.figma_last_modified, figma_file_name: prev.figma_file_name)

    # Copy component sets + variants + assets
    prev.component_sets.includes(:variants, :figma_assets).each do |cs|
      new_cs = ff.component_sets.create!(
        cs.attributes.except("id", "figma_file_id", "created_at", "updated_at")
      )
      cs.variants.each do |v|
        new_cs.variants.create!(
          v.attributes.except("id", "component_set_id", "created_at", "updated_at")
        )
      end
      cs.figma_assets.each do |a|
        FigmaAsset.create!(
          a.attributes.except("id", "component_id", "component_set_id", "created_at", "updated_at")
            .merge("component_set_id" => new_cs.id)
        )
      end
    end

    # Copy standalone components + assets
    prev.components.includes(:figma_assets).each do |c|
      new_c = ff.components.create!(
        c.attributes.except("id", "figma_file_id", "created_at", "updated_at")
      )
      c.figma_assets.each do |a|
        FigmaAsset.create!(
          a.attributes.except("id", "component_id", "component_set_id", "created_at", "updated_at")
            .merge("component_id" => new_c.id)
        )
      end
    end

    ff.update!(status: "ready", progress: ff.progress.merge(
      "completed_at" => Time.current.iso8601,
      "message" => "Unchanged, copied from v#{prev.version}"
    ))
  end

  def maybe_finalize_design_system(ff)
    ds = ff.design_system
    return unless ds

    siblings = ds.figma_files.where(version: ff.version)
    return if siblings.where(status: %w[pending importing converting comparing]).where.not(id: ff.id).exists?

    if siblings.where(status: "error").exists?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "One or more files failed"))
      FigmaWorkerShutdownJob.set(wait: FigmaWorkerShutdownJob::IDLE_TIMEOUT).perform_later
    elsif siblings.all? { |s| s.status == "ready" }
      # All files were unchanged and copied — finalize DS immediately
      ds.update!(status: "ready", progress: ds.progress.merge("completed_at" => Time.current.iso8601))
      FigmaWorkerShutdownJob.set(wait: FigmaWorkerShutdownJob::IDLE_TIMEOUT).perform_later
    end
  end
end
