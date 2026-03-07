require "json"

class JsonToJsx
  def call(tree)
    render_node(tree, 0).rstrip
  end

  private

  def render_node(node, depth)
    element  = node["component"]
    # Separate slot props from regular props
    regular_props = {}
    slot_props = {}

    node.each do |k, v|
      next if k == "component"
      if v.is_a?(Array) && v.any? { |x| x.is_a?(Hash) && x["component"] }
        slot_props[k] = v
      elsif k == "children"
        slot_props["children"] = v
      else
        regular_props[k] = v
      end
    end

    indent = "  " * depth
    open   = "<#{element}#{props_str(element, regular_props)}"

    # Render all slot content (children first, then named slots)
    inner_parts = []
    slot_props.each do |_slot_name, slot_content|
      inner_parts << render_children(slot_content, depth + 1)
    end
    inner = inner_parts.join

    return "#{indent}#{open} />\n" if inner.empty?
    "#{indent}#{open}>\n#{inner}#{indent}</#{element}>\n"
  end

  def render_children(c, depth)
    return "" if c.nil? || c == false || (c.is_a?(String) && c.empty?)

    case c
    when String, Numeric
      text_line(c, depth)
    when Array
      c.map { |x|
        if x.is_a?(Hash) && (x["component"])
          render_node(x, depth)
        else
          text_line(x, depth)
        end
      }.join
    when Hash
      render_node(c, depth)
    else
      text_line(c.to_s, depth)
    end
  end

  def text_line(text, depth)
    "#{"  " * depth}#{text}\n"
  end

  def props_str(element, props)
    parts = serialize_props(element, props)
    parts.empty? ? "" : " " + parts.join(" ")
  end

  def serialize_props(element, props)
    keys = props.keys.map(&:to_s).reject do |k|
      v = props[k] || props[k.to_s]
      v.nil? || (v.is_a?(String) && v.empty?)
    end

    priority = %w[id className variant size disabled style]
    aria = ->(k) { k.start_with?("aria-") || k.start_with?("data-") }

    keys.sort_by! do |k|
      [
        (priority.include?(k) ? 0 : (aria.call(k) ? 1 : 2)),
        k
      ]
    end

    keys.each_with_object([]) do |k, acc|
      v = props[k] || props[k.to_s]

      case v
      when TrueClass, FalseClass
        next if v == false
        acc << "#{k}={true}"
      else
        acc << "#{k}=#{serialize_prop_value(k, v)}"
      end
    end
  end

  def serialize_prop_value(key, val)
    return "{null}" if val.nil?

    case val
    when String
      if val.start_with?("__id:")
        "{#{val.sub('__id:', '')}}"
      else
        "\"#{val.gsub('"', '\"')}\""
      end
    when Numeric
      "{#{val}}"
    when TrueClass, FalseClass
      val ? "{true}" : "{false}"
    when Array, Hash
      if key == "style" && val.is_a?(Hash)
        "{{#{JSON.generate(val)}}}"
      else
        "{#{JSON.generate(val)}}"
      end
    else
      "{#{JSON.generate(val)}}"
    end
  end
end
