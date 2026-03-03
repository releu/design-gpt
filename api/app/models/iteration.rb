class Iteration < ApplicationRecord
  belongs_to :design
  belongs_to :render, optional: true
end
