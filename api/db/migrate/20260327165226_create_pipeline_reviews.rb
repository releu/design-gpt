class CreatePipelineReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_reviews do |t|
      t.references :component_set, null: false, foreign_key: true
      t.float :best_match_percent
      t.float :avg_match_percent
      t.string :status, default: "pending", null: false
      t.text :comment
      t.jsonb :ai_analysis, default: {}
      t.jsonb :variant_scores, default: {}
      t.string :comparison_image_path
      t.timestamps
    end

    add_index :pipeline_reviews, :status
  end
end
