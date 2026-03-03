class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.timestamps
    end

    create_table :project_design_systems do |t|
      t.references :project, null: false, foreign_key: true
      t.references :design_system, null: false, foreign_key: true
      t.timestamps
    end

    add_index :project_design_systems, [:project_id, :design_system_id], unique: true
  end
end
