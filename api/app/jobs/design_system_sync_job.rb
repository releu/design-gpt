class DesignSystemSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(design_system_id, _new_version) { "ds_sync_#{design_system_id}" }, to: 1

  # Estimated MB per component (full JSON tree in memory + processing overhead).
  # DS #67: ~2246 components peaked at ~2GB → ~0.75 MB/component + base.
  MB_PER_COMPONENT = 0.8
  BASE_MEMORY_MB = 200

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

    # Probe files to estimate memory needs and pick dyno size
    scale_figma_worker_for(source_files)

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

    # Enqueue import jobs for each file (serialized by figma_api concurrency limit)
    new_files.each do |ff|
      FigmaFileImportJob.perform_later(ff.id)
    end
  rescue => e
    ds.update!(status: "error", progress: ds.progress.merge("error" => e.message))
    raise
  end

  private

  def scale_figma_worker_for(source_files)
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    max_components = 0

    source_files.each do |ff|
      next unless ff.figma_file_key.present?
      counts = figma.file_component_counts(ff.figma_file_key)
      total = counts[:components] + counts[:component_sets]
      max_components = total if total > max_components
      puts "[DesignSystemSyncJob] File #{ff.figma_file_key}: #{counts[:components]} components, #{counts[:component_sets]} sets"
    rescue => e
      puts "[DesignSystemSyncJob] Failed to probe #{ff.figma_file_key}: #{e.message}"
    end

    estimated_mb = BASE_MEMORY_MB + (max_components * MB_PER_COMPONENT)
    dyno_size = HerokuScaler.pick_dyno_size(estimated_mb.to_i)
    puts "[DesignSystemSyncJob] Estimated memory: #{estimated_mb.to_i}MB → dyno size: #{dyno_size}"

    HerokuScaler.scale_figma_worker(dyno_size)
  end
end
