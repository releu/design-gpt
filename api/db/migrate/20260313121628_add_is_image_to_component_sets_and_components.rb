class AddIsImageToComponentSetsAndComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :component_sets, :is_image, :boolean, default: false, null: false
    add_column :components, :is_image, :boolean, default: false, null: false
  end
end
