class AddReactCodeCompiledToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :react_code_compiled, :text
  end
end
