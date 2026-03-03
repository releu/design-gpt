class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.json :payload
      t.string :state, :default => "pending"
    end
  end
end
