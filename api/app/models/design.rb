class Design < ApplicationRecord
  has_many :iterations
  has_many :chat_messages
  has_many :exports, dependent: :destroy
  belongs_to :user
  belongs_to :design_system, optional: true

  def figma_files
    design_system&.current_figma_files || FigmaFile.none
  end

  STATUSES = %w[draft generating ready error].freeze
  validates :status, inclusion: { in: STATUSES }

  before_create :set_default_name

  def generate
    update!(status: "generating")

    chat_messages.create! do |m|
      m.author = "user"
      m.message = prompt
    end

    create_new_iteration(prompt)
    design_last_iteration
  end

  def improve(prompt)
    update!(status: "generating")

    create_new_iteration(prompt)

    chat_messages.create! do |m|
      m.author = "user"
      m.message = prompt
    end

    design_last_iteration
  end

  def design_last_iteration
    i = iterations.last

    ordered = iterations.order(:id).to_a
    chat_context = ordered.each_with_index.map { |iter, idx|
      "[Iteration #{idx + 1}] #{iter.comment}"
    }.join("\n")

    previous_jsx = ordered[0...-1].reverse.find { |iter| iter.jsx.present? }&.jsx
    if previous_jsx
      chat_context += "\n\n[Current JSX]\n#{previous_jsx}"
    end

    gen = DesignGenerator.new(self)
    task = gen.generate_task(chat_context)

    m = chat_messages.create! do |m|
      m.author = "designer"
      m.message = ""
      m.state = "thinking"
    end

    AiRequestJob.perform_later(task.id, i.id, m.id, :set_jsx)
  end

  def render_last_iteration
    ScreenshotJob.perform_later(iterations.last.id)
  end

  def create_new_iteration(text)
    iterations.create! do |i|
      i.comment = text
      i.design_system = design_system
    end
  end

  def duplicate
    new_design = user.designs.create!(
      prompt: prompt,
      name: "#{name} (copy)",
      status: "ready",
      design_system: design_system
    )

    last_iter = iterations.order(:id).last
    if last_iter
      new_design.iterations.create!(comment: last_iter.comment, jsx: last_iter.jsx)
    end

    new_design
  end

  def last_jsx
    iterations.order(:id).last&.jsx
  end

  def last_screenshot
    iterations.order(:id).last&.render
  end

  def to_frontend_json
    {
      id: id,
      name: name,
      prompt: prompt,
      status: status,
      design_system_id: design_system_id,
      created_at: created_at,
      updated_at: updated_at,
      iterations: iterations.order(:id).map do |i|
        {
          id: i.id,
          text: i.comment,
          jsx: i.jsx,
          tree: i.tree,
          completed: i.jsx?,
          has_screenshot: i.render_id.present?,
          share_code: i.share_code
        }
      end,
      chat: chat_messages.order(:id).map(&:as_frontend_json)
    }
  end

  private

  def set_default_name
    self.name ||= generate_short_name || prompt&.truncate(60) || "Untitled Design"
  end

  def generate_short_name
    return nil if prompt.blank?

    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

    res = HTTP
      .auth("Bearer #{ENV.fetch('OPENAI_API_KEY')}")
      .post("https://api.openai.com/v1/responses", json: {
        model: "gpt-4.1-nano",
        input: "Describe this design request in 24 characters or less. Return only the short name, nothing else.\n\nRequest: #{prompt}"
      }, ssl_context: ctx)
      .body.to_s

    parsed = JSON.parse(res)
    text = parsed.dig("output", 0, "content", 0, "text")
    text&.strip&.truncate(24) || nil
  rescue => e
    Rails.logger.warn("Short name generation failed: #{e.message}")
    nil
  end
end
