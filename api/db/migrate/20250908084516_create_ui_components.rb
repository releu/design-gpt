class CreateUiComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :ui_components do |t|
      t.integer :ui_library_id
      t.string :name
      t.text :prompt
    end
  end
end
