class FigmaAsset < ApplicationRecord
  belongs_to :component, optional: true
  belongs_to :component_set, optional: true

  TYPES = %w[svg image vector].freeze

  validates :node_id, presence: true
  validates :asset_type, presence: true, inclusion: { in: TYPES }


  scope :svgs, -> { where(asset_type: "svg") }
  scope :images, -> { where(asset_type: "image") }
  scope :vectors, -> { where(asset_type: "vector") }

  def owner
    component || component_set
  end


end
