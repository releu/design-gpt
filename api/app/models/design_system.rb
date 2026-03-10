class DesignSystem < ApplicationRecord
  belongs_to :user
  has_many :design_system_libraries, dependent: :destroy
  has_many :figma_files, through: :design_system_libraries

  validates :name, presence: true
end
