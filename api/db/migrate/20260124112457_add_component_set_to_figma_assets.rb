class AddComponentSetToFigmaAssets < ActiveRecord::Migration[8.0]
  def change
    add_reference :figma_assets, :component_set, null: true, foreign_key: true
    change_column_null :figma_assets, :component_id, true
  end
end
