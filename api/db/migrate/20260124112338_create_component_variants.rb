class CreateComponentVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :component_variants do |t|
      t.references :component_set, null: false, foreign_key: true
      t.string :node_id, null: false
      t.string :name
      t.jsonb :figma_json, default: {}
      t.text :react_code
      t.text :react_code_compiled
      t.boolean :is_default, default: false
    end

    add_index :component_variants, :node_id
    add_index :component_variants, [:component_set_id, :node_id], unique: true
  end
end
