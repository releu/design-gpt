class ExpandShareCodeLimit < ActiveRecord::Migration[8.0]
  def change
    change_column :iterations, :share_code, :string, limit: 10
  end
end
