class AddComponentSetAndFileNameToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :component_set_id, :string
    add_column :components, :component_set_name, :string
    add_column :components, :figma_file_name, :string
  end
end
