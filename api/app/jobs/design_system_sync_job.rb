class DesignSystemSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(design_system_id, _new_version) { "ds_sync_#{design_system_id}" }, to: 1


  def perform(design_system_id, new_version)
    ds = DesignSystem.find(design_system_id)
    ds.update!(status: "importing", progress: ds.progress.merge("step" => "importing"))

    # Source files are at the previous version (version was already bumped to new_version by sync_async)
    previous_version = new_version - 1
    source_files = ds.figma_files_for_version(previous_version).to_a

    if source_files.empty?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "No figma files to sync"))
      return
    end

    # Scale up figma_worker — even unchanged files need the big worker
    # for the memory-heavy copy_from_previous_version operation.
    HerokuScaler.scale_up_figma_worker

    # Clean up leftover files from a previous failed sync at this version
    ds.figma_files.where(version: new_version).destroy_all

    new_files = source_files.map do |ff|
      ds.figma_files.create!(
        user: ds.user,
        name: ff.name,
        figma_url: ff.figma_url,
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,
        version: new_version,
        status: "pending",
        progress: { "started_at" => Time.current.iso8601 }
      )
    end

    # Enqueue all import jobs on the figma queue (big worker) — even unchanged
    # files need it because copy_from_previous_version loads all components,
    # variants, and assets into memory, which exceeds the basic worker's quota.
    new_files.each do |ff|
      FigmaFileImportJob.perform_later(ff.id)
    end
  rescue => e
    ds.update!(status: "error", progress: ds.progress.merge("error" => e.message))
    raise
  end

end
