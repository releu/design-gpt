class CreateExports < ActiveRecord::Migration[8.0]
  def change
    create_table :exports do |t|
      t.references :design, null: false, foreign_key: true
      t.references :iteration, null: false, foreign_key: { to_table: :iterations }
      t.string :format, null: false  # image, react, figma
      t.string :status, default: "pending", null: false  # pending, processing, ready, error
      t.string :file_path
      t.text :error_message
      t.timestamps
    end
  end
end
