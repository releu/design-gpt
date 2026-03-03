class CreateFigmaAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :figma_assets do |t|
      t.references :component, null: false, foreign_key: true
      t.string :node_id, null: false
      t.string :name
      t.string :asset_type, null: false
      t.text :content
    end

    add_index :figma_assets, :node_id
    add_index :figma_assets, [:component_id, :node_id], unique: true
  end
end
