class RemoveProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :design_component_libraries do |t|
      t.references :design, null: false, foreign_key: true
      t.references :component_library, null: false, foreign_key: true
      t.timestamps
    end
    add_index :design_component_libraries, [:design_id, :component_library_id],
      unique: true, name: "idx_design_component_libraries_unique"

    add_reference :designs, :user, foreign_key: true   # nullable; backfilled below
    # In dev/test the DB is reset via schema:load so no data migration needed

    remove_foreign_key :designs, :projects
    remove_reference :designs, :project
    remove_column :designs, :component_library_id

    remove_foreign_key :project_component_libraries, :projects
    remove_foreign_key :project_component_libraries, :component_libraries
    drop_table :project_component_libraries

    remove_foreign_key :projects, :users
    drop_table :projects
  end
end
