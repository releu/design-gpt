class CreateDesigns < ActiveRecord::Migration[8.0]
  def change
    create_table :designs do |t|
      t.string :prompt
      t.integer :user_id
    end
  end
end
