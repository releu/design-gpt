class AddLibraryUrlsToDesignSystems < ActiveRecord::Migration[8.0]
  def change
    add_column :design_systems, :library_urls, :jsonb, default: []
  end
end
