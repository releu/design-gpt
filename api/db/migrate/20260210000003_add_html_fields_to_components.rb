class AddHtmlFieldsToComponents < ActiveRecord::Migration[8.0]
  def change
    # HTML conversion output (FigmaToHtml)
    add_column :components, :html_code, :text
    add_column :components, :css_code, :text

    # Import status and visual diff result
    add_column :components, :status, :string, default: "pending"
    add_column :components, :match_percent, :float
    add_column :components, :error_message, :text
    add_column :components, :enabled, :boolean, default: true

    # Remove redundant svg column (use figma_assets instead)
    remove_column :components, :svg, :text
  end
end
