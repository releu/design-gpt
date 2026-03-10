class DesignSystemLibrary < ApplicationRecord
  belongs_to :design_system
  belongs_to :figma_file
end
