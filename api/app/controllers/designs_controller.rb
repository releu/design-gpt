class DesignsController < ApplicationController
  before_action :require_auth

  def index
    designs = current_user.designs.order(created_at: :desc)
    render json: designs.map { |d|
      {
        id: d.id,
        name: d.name,
        prompt: d.prompt,
        status: d.status,
        design_system_id: d.design_system_id,
        has_jsx: d.last_jsx.present?,
        created_at: d.created_at,
        updated_at: d.updated_at
      }
    }
  end

  def create
    ds = resolve_design_system
    design = current_user.designs.create!(
      prompt: design_params[:prompt],
      name: design_params[:name],
      design_system: ds,
      status: "draft"
    )

    if ds
      begin
        design.generate
      rescue => e
        design.update!(status: "error")
        Rails.logger.error("Design generation failed: #{e.message}")
      end
    else
      design.update!(status: "ready")
    end

    render json: { id: design.id, status: design.status }, status: :created
  end

  def show
    design = find_accessible_design(params[:id])
    render json: design.to_frontend_json.merge(is_owner: design.user_id == current_user.id)
  end

  def update
    design = find_user_design(params[:id])
    design.update!(design_update_params)
    render json: { id: design.id, name: design.name, design_system_id: design.design_system_id }
  end

  def destroy
    design = find_user_design(params[:id])
    design.destroy!
    head :no_content
  end

  def improve
    design = find_user_design(params[:design_id])

    comment = params[:comment] || params[:message]
    if params[:messages].present?
      # Full chat history provided — use the last user message as the improvement prompt
      messages = Array(params[:messages])
      comment = messages.last&.dig("content") || messages.last&.dig("message") || comment
    end

    design.improve(comment)
    render json: { id: design.id }
  end

  def rebuild
    design = find_user_design(params[:id])
    design.rebuild
    render json: design.to_frontend_json.merge(is_owner: true)
  end

  def save_code
    design = find_user_design(params[:id])
    iteration = design.iterations.create!(
      jsx: params[:jsx],
      tree: params[:tree],
      comment: params[:comment] || "Manual edit",
      design_system: design.design_system
    )
    design.update!(status: "ready")
    render json: { id: design.id, iteration_id: iteration.id }
  end

  def reset
    design = find_user_design(params[:id])
    iterations = design.iterations.order(:id)

    if iterations.count <= 1
      return render json: { error: "No previous iteration to revert to" }, status: :unprocessable_entity
    end

    iterations.last.destroy!
    design.update!(status: "ready")

    render json: { id: design.id, status: design.status }
  end

  def duplicate
    design = find_accessible_design(params[:id])
    new_design = design.duplicate

    render json: { id: new_design.id, name: new_design.name }, status: :created
  end

  def export_image
    design = find_accessible_design(params[:id])
    render_record = design.last_screenshot

    if render_record&.image.present?
      send_data render_record.image, type: "image/png", disposition: "inline",
        filename: "#{design.name.parameterize}-#{design.id}.png"
    else
      head :not_found
    end
  end

  def export_react
    design = find_accessible_design(params[:id])
    jsx = design.last_jsx

    if jsx.blank?
      head :not_found
      return
    end

    zip_data = Exports::ReactProjectBuilder.new(design).build
    send_data zip_data, type: "application/zip", disposition: "attachment",
      filename: "#{design.name.parameterize}-react.zip"
  end

  def render_to_figma
    design = find_user_design(params[:id])
    file_key = params[:file_key].presence || design.design_system&.figma_working_file_key || design.figma_files.first&.figma_file_key

    if file_key.blank?
      return render json: { error: "file_key is required (no Figma files linked to design system)" }, status: :unprocessable_entity
    end

    iteration = design.iterations.order(:id).last
    unless iteration&.tree
      return render json: { error: "No design tree to render" }, status: :unprocessable_entity
    end

    design.update!(figma_render_status: "queued", figma_render_result: nil)
    FigmaRenderJob.perform_later(design.id, file_key)

    render json: { id: design.id, figma_render_status: "queued" }
  end

  def export_figma
    design = find_accessible_design(params[:id])
    iteration = design.iterations.order(:id).last

    if iteration&.jsx.blank?
      head :not_found
      return
    end

    tree = iteration.tree
    if tree && design.design_system
      builder = Exports::FigmaTreeBuilder.new(design)
      tree = builder.build(tree)
    end

    render json: {
      design_id: design.id,
      name: design.name,
      tree: tree,
      jsx: iteration.jsx,
      design_system_id: design.design_system_id
    }
  end

  private

  def design_params
    params.require(:design).permit(:prompt, :name, :design_system_id)
  end

  def resolve_design_system
    ds_id = params.dig(:design, :design_system_id)
    return nil unless ds_id.present?
    current_user.design_systems.find_by(id: ds_id) ||
      DesignSystem.where(is_public: true).find(ds_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def design_update_params
    params.require(:design).permit(:name, :design_system_id)
  end

  def find_user_design(id)
    current_user.designs.find(id)
  end

  def find_accessible_design(id)
    accessible_designs.find(id)
  end

  def accessible_designs
    Design.all
  end
end
