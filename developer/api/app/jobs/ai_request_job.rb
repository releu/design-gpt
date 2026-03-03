class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(task_id, iteration_id = nil, message_id = nil, action = nil)
    task = AiTask.find(task_id)

    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

    raw_res = HTTP
      .auth("Bearer #{ENV.fetch('OPENAI_API_KEY')}")
      .post("https://api.openai.com/v1/responses", json: task.payload, ssl_context: ctx)
      .body.to_s

    parsed = JSON.parse(raw_res)
    if parsed["error"]
      logger.error "[AiRequestJob] OpenAI error: #{parsed["error"]}"
      logger.error "[AiRequestJob] Payload sent: #{task.payload.to_json}"
      raise "OpenAI API error: #{parsed["error"]}"
    end

    task.update!(result: parsed, state: "completed")

    if iteration_id && action
      i = Iteration.find(iteration_id)
      m = ChatMessage.find(message_id)

      case action
      when :set_jsx
        i.update!(jsx: task.jsx)
        m.update!(state: "completed", message: "Done. Version ##{i.id}")
        i.design.update!(status: "ready")
        i.design.render_last_iteration
      when :post_design_review
        m.update!(state: "completed", message: task.text_response)
      end
    end
  rescue => e
    task&.update(state: "error", result: { "error" => e.message })

    if iteration_id && action == :set_jsx
      design = Iteration.find_by(id: iteration_id)&.design
      design&.update(status: "error")

      if message_id
        ChatMessage.find_by(id: message_id)&.update(
          state: "completed",
          message: "Generation failed: #{e.message}"
        )
      end
    end

    raise
  end
end
