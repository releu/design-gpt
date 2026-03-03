class AddAuth0ToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auth0_id, :string
    add_column :users, :email, :string
    add_index :users, :auth0_id, :unique => true
  end
end
