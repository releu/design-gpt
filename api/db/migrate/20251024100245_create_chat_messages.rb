class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.integer :design_id
      t.string :author
      t.text :message
    end
  end
end
