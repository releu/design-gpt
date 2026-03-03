class AddVisualDiffToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :diff_image_path, :string
    add_column :components, :figma_screenshot_path, :string
    add_column :components, :react_screenshot_path, :string

    add_column :component_variants, :match_percent, :float
    add_column :component_variants, :diff_image_path, :string
    add_column :component_variants, :figma_screenshot_path, :string
    add_column :component_variants, :react_screenshot_path, :string
  end
end
