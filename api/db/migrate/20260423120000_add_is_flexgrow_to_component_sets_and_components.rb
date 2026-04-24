class AddIsFlexgrowToComponentSetsAndComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :component_sets, :is_flexgrow, :boolean, default: false, null: false
    add_column :components, :is_flexgrow, :boolean, default: false, null: false
  end
end
