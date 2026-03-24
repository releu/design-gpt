class DesignSystem < ApplicationRecord
  belongs_to :user
  has_many :designs, dependent: :nullify
  has_many :figma_files, dependent: :destroy

  validates :name, presence: true

  STATUSES = %w[pending importing converting ready error].freeze
  validates :status, inclusion: { in: STATUSES }

  def current_figma_files
    figma_files.where(version: version)
  end

  def figma_files_for_version(v)
    figma_files.where(version: v)
  end

  def sync_async
    # Atomic status guard: only transition to "pending" if not already syncing.
    # Version is NOT bumped here — it stays at the current value so iterations
    # created during the sync still resolve to the last ready version.
    # Version is bumped to new_version only when the sync completes successfully.
    new_version = version + 1
    rows = self.class.where(id: id)
      .where.not(status: %w[pending importing converting])
      .update_all(["status = ?, progress = ?::jsonb", "pending",
        { "started_at" => Time.current.iso8601 }.to_json])
    return if rows == 0

    reload
    DesignSystemSyncJob.perform_later(id, new_version)
    new_version
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
  end
end
