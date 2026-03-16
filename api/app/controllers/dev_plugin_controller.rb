class DevPluginController < ApplicationController
  # In-memory state for dev loop
  @@trigger = nil
  @@result = nil

  # GET /api/plugin/dev_bundle — serve fresh renderer JS
  def bundle
    path = Rails.root.join("../figma-plugin/dist/dev-bundle.js")
    if File.exist?(path)
      render plain: File.read(path), content_type: "application/javascript"
    else
      head :not_found
    end
  end

  # POST /api/plugin/dev_trigger — Claude calls this to start a render
  def trigger
    @@trigger = { action: "run", code: params[:code] || "dev-vlxljd", triggered_at: Time.now }
    @@result = nil
    render json: { ok: true }
  end

  # GET /api/plugin/dev_poll — plugin polls this for pending commands
  def poll
    if @@trigger && @@trigger[:triggered_at] > 10.seconds.ago
      trigger = @@trigger
      @@trigger = nil
      render json: trigger.except(:triggered_at)
    else
      render json: { action: "none" }
    end
  end

  # POST /api/plugin/dev_result — plugin posts render result
  def result
    @@result = { status: params[:status], error: params[:error], frame_name: params[:frame_name], logs: params[:logs], at: Time.now.iso8601 }
    render json: { ok: true }
  end

  # GET /api/plugin/dev_result — Claude checks render result
  def get_result
    render json: (@@result || { status: "pending" })
  end
end
