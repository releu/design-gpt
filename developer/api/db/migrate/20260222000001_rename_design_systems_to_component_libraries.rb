class RenameDesignSystemsToComponentLibraries < ActiveRecord::Migration[8.0]
  def change
    # Rename main tables
    rename_table :design_systems, :component_libraries
    rename_table :project_design_systems, :project_component_libraries

    # Rename foreign key columns
    rename_column :components, :design_system_id, :component_library_id
    rename_column :component_sets, :design_system_id, :component_library_id
    rename_column :project_component_libraries, :design_system_id, :component_library_id
    rename_column :designs, :design_system_id, :component_library_id
  end
end
