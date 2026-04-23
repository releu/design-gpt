class AddActionToChatMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_messages, :action, :string
  end
end
