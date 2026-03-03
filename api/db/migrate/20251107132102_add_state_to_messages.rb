class AddStateToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_messages, :state, :string, :default => "completed"
  end
end
