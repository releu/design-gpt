class CreateDesignSystemGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :design_systems do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :design_system_libraries do |t|
      t.references :design_system, null: false, foreign_key: true
      t.references :component_library, null: false, foreign_key: true
      t.timestamps
    end

    add_index :design_system_libraries, [:design_system_id, :component_library_id],
      unique: true, name: "idx_design_system_libraries_unique"
  end
end
