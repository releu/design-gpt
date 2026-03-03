class AddStatusToComponentSets < ActiveRecord::Migration[8.0]
  def change
    add_column :component_sets, :status, :string, default: "pending"
    add_column :component_sets, :error_message, :text
  end
end
