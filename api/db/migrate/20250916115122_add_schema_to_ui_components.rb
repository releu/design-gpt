class AddSchemaToUiComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :ui_components, :schema, :json
  end
end
