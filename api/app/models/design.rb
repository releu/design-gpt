class Design < ApplicationRecord
  has_many :iterations
  has_many :chat_messages
  has_many :exports, dependent: :destroy
  belongs_to :user
  has_many :design_component_libraries, dependent: :destroy
  has_many :component_libraries, through: :design_component_libraries

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
    refresh_component_libraries_to_latest!

    create_new_iteration(prompt)

    chat_messages.create! do |m|
      m.author = "user"
      m.message = prompt
    end

    design_last_iteration
  end

  def design_last_iteration
    i = iterations.last

    chat_context = iterations.order(:id).map(&:comment).join("\n\n")

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
      i.component_library_ids = component_libraries.pluck(:id)
    end
  end

  def refresh_component_libraries_to_latest!
    design_component_libraries.includes(:component_library).each do |dcl|
      lib = dcl.component_library
      latest = lib.source.latest_version
      if latest.id != lib.id
        dcl.update!(component_library_id: latest.id)
      end
    end
    reload
  end

  def duplicate
    new_design = user.designs.create!(
      prompt: prompt,
      name: "#{name} (copy)",
      status: "ready"
    )

    component_libraries.each do |lib|
      new_design.design_component_libraries.create!(component_library: lib)
    end

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
      component_library_ids: component_library_ids,
      created_at: created_at,
      updated_at: updated_at,
      iterations: iterations.order(:id).map do |i|
        {
          id: i.id,
          text: i.comment,
          jsx: i.jsx,
          completed: i.jsx?,
          has_screenshot: i.render_id.present?
        }
      end,
      chat: chat_messages.order(:id).map(&:as_frontend_json)
    }
  end

  private

  def set_default_name
    self.name ||= prompt&.truncate(60) || "Untitled Design"
  end
end
