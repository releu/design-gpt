class AddLinksBetweenModels < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_messages, :iteration_id, :integer
    remove_column :designs, :schemas
    remove_column :designs, :descriptions
    add_column :designs, :design_system_id, :integer
    rename_table :tasks, :ai_tasks
  end
end
