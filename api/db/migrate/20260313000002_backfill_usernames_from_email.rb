class BackfillUsernamesFromEmail < ActiveRecord::Migration[8.0]
  def up
    User.where.not(email: [nil, ""]).find_each do |user|
      username = user.email.split("@").first
      user.update_column(:username, username)
    end
  end

  def down
    # no-op
  end
end
