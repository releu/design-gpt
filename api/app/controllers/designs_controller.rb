class DesignsController < ApplicationController
  before_action :require_auth

  def index
    designs = accessible_designs.includes(:figma_files).order(created_at: :desc)
    render json: designs.map { |d|
      {
        id: d.id,
        name: d.name,
        prompt: d.prompt,
        status: d.status,
        figma_file_ids: d.figma_file_ids,
        has_jsx: d.last_jsx.present?,
        created_at: d.created_at,
        updated_at: d.updated_at
      }
    }
  end

  def create
    library_ids = resolve_figma_file_ids

    design = current_user.designs.create!(prompt: design_params[:prompt], name: design_params[:name], status: "draft")

    library_ids.each do |id|
      design.design_figma_files.create!(figma_file_id: id)
    end

    if library_ids.any?
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
    render json: design.to_frontend_json
  end

  def update
    design = find_user_design(params[:id])
    design.update!(design_update_params)
    render json: { id: design.id, name: design.name }
  end

  def destroy
    design = find_user_design(params[:id])
    design.destroy!
    head :no_content
  end

  def improve
    design = find_accessible_design(params[:design_id])

    comment = params[:comment] || params[:message]
    if params[:messages].present?
      # Full chat history provided — use the last user message as the improvement prompt
      messages = Array(params[:messages])
      comment = messages.last&.dig("content") || messages.last&.dig("message") || comment
    end

    design.improve(comment)
    render json: { id: design.id }
  end

  def reset
    design = find_accessible_design(params[:id])
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

  def export_figma
    design = find_accessible_design(params[:id])
    iteration = design.iterations.order(:id).last

    if iteration&.jsx.blank?
      head :not_found
      return
    end

    ai_task = AiTask.order(:id).last
    tree = ai_task&.args

    render json: {
      design_id: design.id,
      name: design.name,
      tree: tree,
      jsx: iteration.jsx,
      figma_file_ids: design.figma_file_ids
    }
  end

  private

  def design_params
    params.require(:design).permit(:prompt, :name, :design_system_id, figma_file_ids: [])
  end

  def resolve_figma_file_ids
    ds_id = params.dig(:design, :design_system_id)
    if ds_id.present?
      ds = current_user.design_systems.find(ds_id)
      ds.figma_file_ids
    else
      Array(params.dig(:design, :figma_file_ids))
    end
  rescue ActiveRecord::RecordNotFound
    []
  end

  def design_update_params
    params.require(:design).permit(:name)
  end

  def find_user_design(id)
    current_user.designs.find(id)
  end

  def find_accessible_design(id)
    accessible_designs.find(id)
  end

  def accessible_designs
    current_user.designs
  end
end
