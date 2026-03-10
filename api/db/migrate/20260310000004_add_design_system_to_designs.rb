class AddDesignSystemToDesigns < ActiveRecord::Migration[8.0]
  def up
    add_reference :designs, :design_system, null: true, foreign_key: true

    # Migrate: for each design, find or create a design_system from its figma_files
    execute <<~SQL
      UPDATE designs
      SET design_system_id = (
        SELECT dsl.design_system_id
        FROM design_figma_files dff
        JOIN design_system_libraries dsl ON dsl.figma_file_id = dff.figma_file_id
        WHERE dff.design_id = designs.id
        LIMIT 1
      )
    SQL

    drop_table :design_figma_files
  end

  def down
    create_table :design_figma_files do |t|
      t.bigint :design_id, null: false
      t.bigint :figma_file_id, null: false
      t.timestamps
      t.index [:design_id, :figma_file_id], unique: true, name: "idx_design_component_libraries_unique"
      t.index :design_id
      t.index :figma_file_id
    end
    add_foreign_key :design_figma_files, :designs
    add_foreign_key :design_figma_files, :figma_files

    remove_reference :designs, :design_system
  end
end
