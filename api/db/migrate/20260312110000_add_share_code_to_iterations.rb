class AddShareCodeToIterations < ActiveRecord::Migration[8.0]
  def change
    add_column :iterations, :share_code, :string, limit: 6
    add_index :iterations, :share_code, unique: true
  end
end
