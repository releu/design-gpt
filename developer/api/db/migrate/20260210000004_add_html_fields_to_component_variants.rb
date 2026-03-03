class AddHtmlFieldsToComponentVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :component_variants, :html_code, :text
    add_column :component_variants, :css_code, :text
  end
end
