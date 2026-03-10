class Iteration < ApplicationRecord
  belongs_to :design
  belongs_to :render, optional: true
  belongs_to :design_system, optional: true
end
