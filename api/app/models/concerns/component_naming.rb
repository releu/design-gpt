module ComponentNaming
  extend ActiveSupport::Concern

  # Convert a Figma component name to PascalCase React name
  # e.g. "Size=M, State=default" → "Button", "my-component" → "MyComponent"
  # Already-valid PascalCase names (e.g. "SiteSelector") are preserved as-is.
  def to_component_name(name)
    base_name = name.to_s.split(",").first&.split("=")&.last || name.to_s
    base_name = base_name.strip

    # Already valid PascalCase: starts with uppercase, only alphanumeric
    return base_name if base_name.match?(/\A[A-Z][a-zA-Z0-9]*\z/)

    result = base_name
      .gsub(/[^a-zA-Z0-9\s_-]/, "")
      .split(/[\s_-]+/)
      .map(&:capitalize)
      .join
      .gsub(/^[0-9]+/, "")

    result.presence || "Component"
  end

  # Convert a Figma property name to camelCase React prop name
  # e.g. "Show Icon" → "showIcon", "is-active" → "isActive"
  # Already-valid camelCase names (e.g. "sideColumnItems") are preserved as-is.
  def to_prop_name(name)
    clean_name = name.to_s.gsub(/[^\w\s-]/i, "").strip

    # Already valid camelCase: starts with lowercase, only alphanumeric
    return clean_name if clean_name.match?(/\A[a-z][a-zA-Z0-9]*\z/)

    words = clean_name.split(/[\s_-]+/)
    return "prop" if words.empty? || words.all?(&:empty?)

    words = words.reject(&:empty?)
    return "prop" if words.empty?

    first = words.first.downcase.gsub(/[^a-z0-9]/i, "")
    rest = words[1..].map { |w| w.gsub(/[^a-z0-9]/i, "").capitalize }.join

    result = first + rest
    result = "prop#{result}" if result.match?(/^\d/)
    result.empty? ? "prop" : result
  end
end
