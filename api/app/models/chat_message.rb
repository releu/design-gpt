class ChatMessage < ApplicationRecord
  def html
    message.lines.join("<br />")
  end

  def as_frontend_json
    as_json(:methods => :html)
  end
end
