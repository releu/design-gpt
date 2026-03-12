class AddComponentKeyAndTree < ActiveRecord::Migration[8.0]
  def change
    add_column :component_sets, :component_key, :string
    add_column :component_variants, :component_key, :string
    add_column :components, :component_key, :string
    add_column :iterations, :tree, :jsonb
  end
end
