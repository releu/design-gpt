class AddImportPromptToUiLibraries < ActiveRecord::Migration[8.0]
  def change
    add_column :ui_libraries, :import_prompt, :text
  end
end
