class AddVersioningToDesignSystems < ActiveRecord::Migration[8.0]
  def up
    # 1. DesignSystem gets version + sync status
    add_column :design_systems, :version, :integer, default: 1, null: false
    add_column :design_systems, :status, :string, default: "pending"
    add_column :design_systems, :progress, :jsonb, default: {}

    # 2. FigmaFile gets direct design_system_id (replaces join table)
    add_reference :figma_files, :design_system, null: true, foreign_key: true

    # 3. Iterations get DS version (replaces figma_file_ids)
    add_reference :iterations, :design_system, null: true, foreign_key: true
    add_column :iterations, :design_system_version, :integer

    # 4. Backfill existing data
    execute <<~SQL
      UPDATE figma_files SET design_system_id = dsl.design_system_id
      FROM design_system_libraries dsl
      WHERE figma_files.id = dsl.figma_file_id;
    SQL

    execute <<~SQL
      UPDATE design_systems SET version = 1, status = 'ready'
      WHERE id IN (SELECT DISTINCT design_system_id FROM figma_files WHERE design_system_id IS NOT NULL);
    SQL

    execute <<~SQL
      UPDATE iterations SET
        design_system_id = d.design_system_id,
        design_system_version = 1
      FROM designs d
      WHERE iterations.design_id = d.id
        AND d.design_system_id IS NOT NULL;
    SQL

    # Backfill figma_files.version to match DS version (all existing = version 1)
    execute "UPDATE figma_files SET version = 1 WHERE design_system_id IS NOT NULL"

    # 5. Drop join table and old columns
    drop_table :design_system_libraries
    remove_column :iterations, :figma_file_ids
    remove_foreign_key :figma_files, column: :source_file_id
    remove_column :figma_files, :source_file_id
  end

  def down
    add_column :figma_files, :source_file_id, :bigint
    add_foreign_key :figma_files, :figma_files, column: :source_file_id
    add_column :iterations, :figma_file_ids, :jsonb, default: []

    create_table :design_system_libraries do |t|
      t.references :design_system, null: false, foreign_key: true
      t.references :figma_file, null: false, foreign_key: true
      t.timestamps
      t.index [:design_system_id, :figma_file_id], unique: true, name: "idx_design_system_libraries_unique"
    end

    remove_reference :iterations, :design_system
    remove_column :iterations, :design_system_version
    remove_reference :figma_files, :design_system
    remove_column :design_systems, :version
    remove_column :design_systems, :status
    remove_column :design_systems, :progress
  end
end
