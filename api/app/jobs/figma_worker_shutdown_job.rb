class FigmaWorkerShutdownJob < ApplicationJob
  queue_as :figma

  # Delayed shutdown: check if there's any pending figma work before scaling down.
  # If new work appeared during the delay, skip shutdown.
  IDLE_TIMEOUT = 10.minutes

  def perform
    # Check if any design system is still importing/converting
    active = DesignSystem.where(status: %w[pending importing converting]).exists?

    if active
      puts "[FigmaWorkerShutdown] Active sync in progress, skipping shutdown"
      return
    end

    # Check if any figma files are still pending
    pending_files = FigmaFile.where(status: %w[pending importing converting comparing]).exists?

    if pending_files
      puts "[FigmaWorkerShutdown] Pending files exist, skipping shutdown"
      return
    end

    puts "[FigmaWorkerShutdown] No active work, shutting down figma_worker"
    HerokuScaler.scale_down_figma_worker
  end
end
