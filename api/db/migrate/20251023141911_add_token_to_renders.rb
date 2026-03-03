class AddTokenToRenders < ActiveRecord::Migration[8.0]
  def change
    add_column :renders, :token, :string
    add_index :renders, :token, :unique => true
  end
end
