class AddIncrementalSyncFields < ActiveRecord::Migration[8.0]
  def change
    add_column :figma_files, :figma_last_modified, :string
    add_column :component_sets, :content_hash, :string
    add_column :component_variants, :content_hash, :string
    add_column :components, :content_hash, :string
  end
end
