class AddSourceToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :source, :string, default: "figma", null: false  # figma, upload
    add_column :components, :prop_types, :jsonb, default: {}  # For uploaded components: { label: "string", size: "enum:sm,md,lg" }
  end
end
