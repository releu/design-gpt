class MoveIsPublicToDesignSystems < ActiveRecord::Migration[7.1]
  def change
    add_column :design_systems, :is_public, :boolean, default: false, null: false
    remove_column :figma_files, :is_public, :boolean, default: false, null: false
  end
end
