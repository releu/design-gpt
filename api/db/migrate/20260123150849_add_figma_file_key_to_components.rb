class AddFigmaFileKeyToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :figma_file_key, :string
  end
end
