class AddFigmaRenderToDesigns < ActiveRecord::Migration[8.0]
  def change
    add_column :designs, :figma_render_status, :string
    add_column :designs, :figma_render_result, :jsonb
  end
end
