class CreateImageCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :image_caches do |t|
      t.string :query, null: false, index: { unique: true }
      t.text :url, null: false
      t.integer :width
      t.integer :height
      t.timestamps
    end
  end
end
