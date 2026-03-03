class CreateIterations < ActiveRecord::Migration[8.0]
  def change
    create_table :iterations do |t|
      t.integer :design_id
      t.text :jsx
      t.integer :render_id
      t.string :comment
    end
  end
end
