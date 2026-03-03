class AddProjectToDesigns < ActiveRecord::Migration[8.0]
  def up
    # 1. Add project_id column (nullable initially)
    add_reference :designs, :project, foreign_key: true

    # 2. Create a default project for each user who has designs, and assign designs
    execute <<-SQL
      WITH default_projects AS (
        INSERT INTO projects (user_id, name, created_at, updated_at)
        SELECT DISTINCT d.user_id, 'Default Project', NOW(), NOW()
        FROM designs d
        WHERE d.user_id IS NOT NULL
        RETURNING id, user_id
      )
      UPDATE designs
      SET project_id = default_projects.id
      FROM default_projects
      WHERE designs.user_id = default_projects.user_id;
    SQL

    # 3. Make project_id non-nullable
    change_column_null :designs, :project_id, false

    # 4. Remove user_id from designs (now accessed through project)
    remove_column :designs, :user_id
  end

  def down
    add_column :designs, :user_id, :integer

    # Restore user_id from the project's user
    execute <<-SQL
      UPDATE designs
      SET user_id = projects.user_id
      FROM projects
      WHERE designs.project_id = projects.id;
    SQL

    change_column_null :designs, :project_id, true
    remove_reference :designs, :project, foreign_key: true
  end
end
