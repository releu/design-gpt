class AiTask < ApplicationRecord
  def args
    return nil if result.nil?
    raise "OpenAI API error: #{result["error"]}" if result["error"]
    raise "Unexpected API response: missing 'output'" unless result["output"]

    res = nil
    result["output"].each do |message|
      if message["type"] == "message"
        res = JSON.parse(message["content"][0]["text"])["tree"]
      end
    end

    res
  end

  def jsx
    return nil if result.nil?
    JsonToJsx.new.call(materialize_image_urls(args))
  end

  def text_response
    return nil if result.nil?
    raise "OpenAI API error: #{result["error"]}" if result["error"]
    raise "Unexpected API response: missing 'output'" unless result["output"]

    res = nil
    result["output"].each do |message|
      if message["type"] == "message"
        res = message["content"][0]["text"]
      end
    end

    res
  end

  def materialize_image_urls(obj)
    case obj
    when Hash
      if obj.key?("imageQuery")
        q = obj.delete("imageQuery")
        unless q.nil? || q == ""
          result = ImageCache.search(q.to_s)
          obj["imageUrl"] = result[:url]
        end
      end
      obj.each_value { |v| materialize_image_urls(v) }
    when Array
      obj.each { |v| materialize_image_urls(v) }
    end
    obj
  end
end
