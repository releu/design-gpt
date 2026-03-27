class AddFigmaEmbedToIterations < ActiveRecord::Migration[8.0]
  def change
    add_column :iterations, :figma_frame_id, :string
    add_column :iterations, :figma_file_key, :string
  end
end
