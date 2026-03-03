class AddPublicToComponentLibraries < ActiveRecord::Migration[8.0]
  def change
    add_column :component_libraries, :is_public, :boolean, default: false, null: false
  end
end
