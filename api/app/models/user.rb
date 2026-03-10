class User < ApplicationRecord
  has_many :figma_files
  has_many :design_systems, dependent: :destroy
  has_many :designs, dependent: :destroy

  validates :auth0_id, :uniqueness => true, :allow_nil => true
end
