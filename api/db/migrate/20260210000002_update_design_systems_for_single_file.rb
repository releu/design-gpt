class UpdateDesignSystemsForSingleFile < ActiveRecord::Migration[8.0]
  def change
    # Each design system now represents exactly one Figma file
    add_column :design_systems, :figma_url, :string
    add_column :design_systems, :figma_file_key, :string
    add_column :design_systems, :figma_file_name, :string
    add_column :design_systems, :status, :string, default: "pending"
    add_column :design_systems, :progress, :jsonb, default: {}

    add_index :design_systems, [:user_id, :figma_file_key], unique: true

    # Migrate data from library_urls to figma_url
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE design_systems
          SET figma_url = library_urls->>0
          WHERE library_urls IS NOT NULL AND jsonb_array_length(library_urls) > 0
        SQL
      end
    end

    remove_column :design_systems, :library_urls, :jsonb, default: []
  end
end
