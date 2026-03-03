class AddRendererUrlToUiLibraries < ActiveRecord::Migration[8.0]
  def change
    add_column :ui_libraries, :renderer_url, :string
  end
end
