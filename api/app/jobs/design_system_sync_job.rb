class DesignSystemSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(design_system_id, _new_version) { "ds_sync_#{design_system_id}" }, to: 1

  def perform(design_system_id, new_version)
    ds = DesignSystem.find(design_system_id)
    ds.update!(status: "importing", progress: ds.progress.merge("step" => "importing"))

    # For each unique figma_file_key in the current version, create a new FigmaFile and sync it
    current_files = ds.current_figma_files.to_a

    if current_files.empty?
      ds.update!(status: "error", progress: ds.progress.merge("error" => "No figma files to sync"))
      return
    end

    # Clean up leftover files from a previous failed sync at this version
    ds.figma_files.where(version: new_version).destroy_all

    new_files = current_files.map do |ff|
      new_ff = ds.figma_files.create!(
        user: ds.user,
        name: ff.name,
        figma_url: ff.figma_url,
        figma_file_key: ff.figma_file_key,
        figma_file_name: ff.figma_file_name,

        version: new_version,
        status: "pending",
        progress: { "started_at" => Time.current.iso8601 }
      )
      new_ff.sync_with_figma
      new_ff
    end

    ds.update!(
      version: new_version,
      status: "ready",
      progress: ds.progress.merge("completed_at" => Time.current.iso8601)
    )
  rescue => e
    ds.update!(status: "error", progress: ds.progress.merge("error" => e.message))
    raise
  end
end
