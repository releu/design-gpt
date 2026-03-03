class Export < ApplicationRecord
  belongs_to :design
  belongs_to :iteration

  FORMATS = %w[image react figma].freeze
  STATUSES = %w[pending processing ready error].freeze

  validates :format, inclusion: { in: FORMATS }
  validates :status, inclusion: { in: STATUSES }
end
