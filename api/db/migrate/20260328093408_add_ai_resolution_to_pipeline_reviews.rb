class AddAiResolutionToPipelineReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_reviews, :ai_resolution, :string
  end
end
