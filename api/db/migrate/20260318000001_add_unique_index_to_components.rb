class AddUniqueIndexToComponents < ActiveRecord::Migration[8.0]
  def change
    add_index :components, [:figma_file_id, :node_id], unique: true
  end
end
