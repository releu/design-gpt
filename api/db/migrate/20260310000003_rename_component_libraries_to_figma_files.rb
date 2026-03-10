class RenameComponentLibrariesToFigmaFiles < ActiveRecord::Migration[8.0]
  def change
    # Rename main table
    rename_table :component_libraries, :figma_files

    # Rename join table
    rename_table :design_component_libraries, :design_figma_files

    # Rename foreign key columns in all related tables
    rename_column :figma_files, :source_library_id, :source_file_id
    rename_column :design_figma_files, :component_library_id, :figma_file_id
    rename_column :design_system_libraries, :component_library_id, :figma_file_id
    rename_column :component_sets, :component_library_id, :figma_file_id
    rename_column :components, :component_library_id, :figma_file_id

    # Rename jsonb column on iterations
    rename_column :iterations, :component_library_ids, :figma_file_ids
  end
end
