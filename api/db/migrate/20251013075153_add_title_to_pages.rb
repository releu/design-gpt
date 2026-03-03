class AddTitleToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :title, :string
  end
end
