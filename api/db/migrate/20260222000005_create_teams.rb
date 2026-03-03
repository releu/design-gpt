class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end

    add_index :team_memberships, [:team_id, :user_id], unique: true

    add_reference :projects, :team, foreign_key: true
    add_reference :component_libraries, :team, foreign_key: true
  end
end
