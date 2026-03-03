class CreateDesignSystems < ActiveRecord::Migration[8.0]
  def change
    create_table :design_systems do |t|
      t.integer :user_id
      t.string :name
      t.string :figma_file_key
    end

    add_index :design_systems, :user_id
  end
end
