class AddComponentKeyMapToFigmaFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :figma_files, :component_key_map, :jsonb, default: {}
  end
end
