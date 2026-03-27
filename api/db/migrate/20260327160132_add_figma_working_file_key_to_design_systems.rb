class AddFigmaWorkingFileKeyToDesignSystems < ActiveRecord::Migration[8.0]
  def change
    add_column :design_systems, :figma_working_file_key, :string
  end
end
