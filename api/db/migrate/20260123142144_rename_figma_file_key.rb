class RenameFigmaFileKey < ActiveRecord::Migration[8.0]
  def change
    rename_column :design_systems, :figma_file_key, :figma_url
  end
end
