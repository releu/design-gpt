class EnhanceDesigns < ActiveRecord::Migration[8.0]
  def change
    add_column :designs, :name, :string
    add_column :designs, :status, :string, default: "draft", null: false
    add_column :designs, :created_at, :datetime
    add_column :designs, :updated_at, :datetime
  end
end
