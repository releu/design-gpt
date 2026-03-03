class RemoveFigmaUrlFromDesignSystems < ActiveRecord::Migration[8.0]
  def change
    remove_column :design_systems, :figma_url, :string
  end
end
