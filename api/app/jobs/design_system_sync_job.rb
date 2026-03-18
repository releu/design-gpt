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

    # Check which files have changed via lightweight Figma API call
    figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
    changed_file_keys = detect_changed_files(figma, source_files)

    # Only scale figma_worker if at least one file changed
    if changed_file_keys.any?
      scale_figma_worker_for(figma, source_files, changed_file_keys)
    else
      puts "[DesignSystemSyncJob] All #{source_files.size} files unchanged, skipping worker scale"
    end

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

    # Enqueue import jobs — unchanged files go to default queue (no figma_worker needed),
    # changed files go to figma queue (needs Figma API access)
    new_files.each do |ff|
      if changed_file_keys.include?(ff.figma_file_key)
        FigmaFileImportJob.perform_later(ff.id)
      else
        FigmaFileImportJob.set(queue: :default).perform_later(ff.id)
      end
    end
  rescue => e
    ds.update!(status: "error", progress: ds.progress.merge("error" => e.message))
    raise
  end

  private

  # Check Figma's lastModified for each file and return the set of keys that changed.
  def detect_changed_files(figma, source_files)
    changed = Set.new

    source_files.each do |ff|
      next unless ff.figma_file_key.present?

      # No stored timestamp = first sync with incremental support, treat as changed
      unless ff.figma_last_modified.present?
        changed << ff.figma_file_key
        puts "[DesignSystemSyncJob] File #{ff.figma_file_key} has no stored lastModified, treating as changed"
        next
      end

      meta = figma.get("/v1/files/#{ff.figma_file_key}?depth=1")
      if meta["lastModified"] != ff.figma_last_modified
        changed << ff.figma_file_key
        puts "[DesignSystemSyncJob] File #{ff.figma_file_key} changed (#{ff.figma_last_modified} → #{meta["lastModified"]})"
      else
        puts "[DesignSystemSyncJob] File #{ff.figma_file_key} unchanged"
      end
    rescue => e
      # If we can't check, assume changed to be safe
      changed << ff.figma_file_key
      puts "[DesignSystemSyncJob] Failed to check #{ff.figma_file_key}: #{e.message}, assuming changed"
    end

    changed
  end

  # Only probe and scale for files that actually changed.
  def scale_figma_worker_for(figma, source_files, changed_file_keys)
    max_components = 0

    source_files.each do |ff|
      next unless ff.figma_file_key.present?
      next unless changed_file_keys.include?(ff.figma_file_key)

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

    HerokuScaler.scale_up_figma_worker(dyno_size)
  end
end
