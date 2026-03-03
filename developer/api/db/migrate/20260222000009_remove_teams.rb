class RemoveTeams < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :projects, :teams
    remove_reference :projects, :team

    remove_foreign_key :component_libraries, :teams
    remove_reference :component_libraries, :team

    remove_foreign_key :team_memberships, :teams
    remove_foreign_key :team_memberships, :users
    drop_table :team_memberships

    drop_table :teams
  end
end
