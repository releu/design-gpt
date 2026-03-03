class CreateComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :components do |t|
      t.integer :design_system_id
      t.string :kind
      t.string :node_id, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :prop_definitions, null: false, default: {}
      t.jsonb :deps, null: false, default: []
      t.text :react_code
      t.jsonb :schema
      t.timestamp :updated_at
    end
  end
end
