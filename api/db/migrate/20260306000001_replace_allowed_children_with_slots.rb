class ReplaceAllowedChildrenWithSlots < ActiveRecord::Migration[8.0]
  def change
    remove_column :component_sets, :allowed_children, :jsonb, default: []
    remove_column :components, :allowed_children, :jsonb, default: []
    add_column :component_sets, :slots, :jsonb, default: []
    add_column :components, :slots, :jsonb, default: []
  end
end
