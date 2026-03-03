class User < ApplicationRecord
  has_many :component_libraries
  has_many :design_systems, dependent: :destroy
  has_many :designs, dependent: :destroy

  validates :auth0_id, :uniqueness => true, :allow_nil => true
end
