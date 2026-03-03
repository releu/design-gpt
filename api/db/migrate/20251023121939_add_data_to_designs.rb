class AddDataToDesigns < ActiveRecord::Migration[8.0]
  def change
    add_column :designs, :schemas, :json
    add_column :designs, :descriptions, :json
  end
end
