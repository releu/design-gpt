class PipelineReview < ApplicationRecord
  belongs_to :component_set

  STATUSES = %w[pending need_fix fixing ready_to_review approved].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :component_set_id, uniqueness: true

  scope :need_fix, -> { where(status: "need_fix") }
  scope :ready_to_review, -> { where(status: "ready_to_review") }
  scope :by_match, -> { order(Arel.sql("COALESCE(best_match_percent, 0) ASC")) }
end
