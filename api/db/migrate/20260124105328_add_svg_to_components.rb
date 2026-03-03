class AddSvgToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :svg, :text
  end
end
