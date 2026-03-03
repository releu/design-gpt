class CreateComponentSets < ActiveRecord::Migration[8.0]
  def change
    create_table :component_sets do |t|
      t.references :design_system, null: false, foreign_key: true
      t.string :node_id, null: false
      t.string :name
      t.text :description
      t.string :figma_file_key
      t.string :figma_file_name
      t.jsonb :prop_definitions, default: {}
    end

    add_index :component_sets, :node_id
    add_index :component_sets, [:design_system_id, :node_id], unique: true
  end
end
