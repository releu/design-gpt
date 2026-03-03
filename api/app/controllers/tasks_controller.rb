class TasksController < ApplicationController
  before_action :check_api_auth, :only => [:next, :update]
  before_action :require_auth, :only => [:show]

  def show
    task = AiTask.find(params[:id])
    render :json => task.as_json(:methods => [:jsx])
  end

  def next
    if task = AiTask.where(:state => "pending").order(:id).first
      render :json => task
    else
      render :json => { :status => :no_tasks }
    end
  end

  def update
    task = AiTask.find(params[:id])
    task.update!({
      result: params[:result],
      state: "completed"
    })
    head :ok
  end

  private
  def check_api_auth
    token = request.headers["Authorization"].to_s.split(" ").last

    if token.blank? || token != ENV.fetch("TASKS_TOKEN", "")
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
