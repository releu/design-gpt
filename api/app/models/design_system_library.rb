class DesignSystemLibrary < ApplicationRecord
  belongs_to :design_system
  belongs_to :component_library
end
