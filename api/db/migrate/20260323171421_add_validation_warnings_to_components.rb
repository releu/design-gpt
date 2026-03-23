class AddValidationWarningsToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :component_sets, :validation_warnings, :jsonb, default: []
    add_column :components, :validation_warnings, :jsonb, default: []
  end
end
