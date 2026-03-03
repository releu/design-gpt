class DropRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    drop_table :refresh_tokens if table_exists?(:refresh_tokens)
  end
end
