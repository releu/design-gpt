class RemoveOldShit < ActiveRecord::Migration[8.0]
  def change
    drop_table :features
    drop_table :pages
    drop_table :projects
    drop_table :ui_components
    drop_table :ui_libraries
  end
end
