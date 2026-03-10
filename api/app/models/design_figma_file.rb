class DesignFigmaFile < ApplicationRecord
  belongs_to :design
  belongs_to :figma_file
  validates :figma_file_id, uniqueness: { scope: :design_id }
end
