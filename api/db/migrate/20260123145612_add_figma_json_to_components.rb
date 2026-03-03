class AddFigmaJsonToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :figma_json, :jsonb
  end
end
