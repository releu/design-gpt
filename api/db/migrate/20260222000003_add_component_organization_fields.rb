class AddComponentOrganizationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :is_root, :boolean, default: false, null: false
    add_column :components, :allowed_children, :jsonb, default: []
    add_column :component_sets, :is_root, :boolean, default: false, null: false
    add_column :component_sets, :allowed_children, :jsonb, default: []
  end
end
