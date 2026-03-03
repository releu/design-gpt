class DesignComponentLibrary < ApplicationRecord
  belongs_to :design
  belongs_to :component_library
  validates :component_library_id, uniqueness: { scope: :design_id }
end
