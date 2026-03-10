class AddVersioningToComponentLibraries < ActiveRecord::Migration[8.0]
  def change
    add_column :component_libraries, :source_library_id, :bigint, null: true
    add_column :component_libraries, :version, :integer, null: false, default: 1
    add_index :component_libraries, :source_library_id

    add_column :iterations, :component_library_ids, :jsonb, default: []

    # Drop unique index on (user_id, figma_file_key) — multiple versions now expected
    remove_index :component_libraries, [:user_id, :figma_file_key], unique: true
    add_index :component_libraries, [:user_id, :figma_file_key]

    add_foreign_key :component_libraries, :component_libraries, column: :source_library_id
  end
end
