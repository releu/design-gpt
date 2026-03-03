class ChatMessage < ApplicationRecord
  def html
    if author == "art_director" && message?
      data = JSON.parse(message)
      v = ""
      if data["verdict"] == "shit"
        v = "💩"
      else
        v = "✅"
      end

      %(#{v}<br /><br />#{data["feedback"].lines.join("<br />")})
    else
      message.lines.join("<br />")
    end
  end

  def as_frontend_json
    as_json(:methods => :html)
  end
end
