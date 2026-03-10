class DesignGenerator
  include ComponentNaming

  def initialize(design)
    @design = design
    @libraries = design.figma_files
  end

  def generate_task(prompt)
    raise "No figma files linked" unless @libraries.any?
    raise "No root components configured" unless root_components.any?

    AiTask.create! do |t|
      t.payload = build_payload(prompt)
    end
  end

  private

  def build_payload(prompt)
    {
      model: "gpt-5",
      input: [
        { role: "system", content: [{ type: "input_text", text: system_prompt }] },
        { role: "user", content: [{ type: "input_text", text: prompt }] }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "render_code_args",
          strict: true,
          schema: build_schema
        }
      }
    }
  end

  def system_prompt
    component_list = all_components.map { |name, desc| "- #{name}: #{desc}" }.join("\n")
    <<~PROMPT
      You are a UI designer. You compose interfaces using the provided components.
      Return only JSON matching the schema. No text outside JSON.

      Available components:
      #{component_list}
    PROMPT
  end

  def build_schema
    {
      type: "object",
      additionalProperties: false,
      required: ["tree"],
      properties: {
        tree: { "$ref" => "#/$defs/AllComponents" }
      },
      "$defs" => build_defs
    }
  end

  def build_defs
    defs = {}

    eligible_component_sets.each do |cs|
      name = to_component_name(cs.name)
      next unless reachable_names.include?(name)
      defs[name] = build_component_set_def(cs, name)
    end

    eligible_standalone_components.each do |comp|
      name = to_component_name(comp.name)
      next unless reachable_names.include?(name)
      defs[name] = build_standalone_component_def(comp, name)
    end

    # AllComponents: anyOf only root components
    defs["AllComponents"] = {
      anyOf: root_component_names.map { |n| { "$ref" => "#/$defs/#{n}" } }
    }

    defs
  end

  def collect_reachable(names, visited)
    names.each do |raw_name|
      name = normalize_child_name(raw_name)
      next if visited.include?(name)
      visited << name

      record = component_by_name(name)
      next unless record

      all_slot_children = (record.slots || []).flat_map { |s| s["allowed_children"] || [] }
      children = all_slot_children.map { |c| normalize_child_name(c) }
      collect_reachable(children, visited)
    end
  end

  def build_component_set_def(cs, name)
    props = {}
    required = ["component"]

    props["component"] = { type: "string", const: name }

    (cs.prop_definitions || {}).each do |prop_name, prop_def|
      type = prop_def["type"]
      camel_name = to_prop_name(prop_name)

      case type
      when "VARIANT"
        values = variant_enum_values(cs, prop_name)
        props[camel_name] = { type: "string", enum: values } if values.any?
        required << camel_name if values.any?
      when "TEXT"
        props[camel_name] = { type: "string" }
        required << camel_name
      when "BOOLEAN"
        props[camel_name] = { type: "boolean" }
        required << camel_name
      end
      # Skip INSTANCE_SWAP and other types
    end

    slots = cs.slots || []
    variant_json = cs.default_variant&.figma_json
    prop_defs = cs.prop_definitions || {}

    slots.each do |slot|
      slot_name = slot["name"]
      children = (slot["allowed_children"] || []).map { |c| normalize_child_name(c) }.select { |c| component_name_index.key?(c) }

      if children.length == 1
        props[slot_name] = { type: "array", items: { "$ref" => "#/$defs/#{children.first}" } }
        required << slot_name
      elsif children.any?
        props[slot_name] = {
          type: "array",
          items: { anyOf: children.map { |c| { "$ref" => "#/$defs/#{c}" } } }
        }
        required << slot_name
      end
    end

    # Fallback: if no slots but component has slot instances in its tree, add generic children
    if slots.empty? && has_slot?(variant_json, prop_defs)
      props["children"] = { type: "string" }
      required << "children"
    end

    {
      type: "object",
      additionalProperties: false,
      required: required.uniq,
      properties: props
    }
  end

  def build_standalone_component_def(comp, name)
    props = {}
    required = ["component"]

    props["component"] = { type: "string", const: name }

    # Uploaded components may have prop_definitions
    (comp.prop_definitions || {}).each do |prop_name, prop_def|
      type = prop_def["type"]
      camel_name = to_prop_name(prop_name)

      case type
      when "VARIANT"
        default_val = prop_def["defaultValue"]
        props[camel_name] = { type: "string" }
        required << camel_name
      when "TEXT"
        props[camel_name] = { type: "string" }
        required << camel_name
      when "BOOLEAN"
        props[camel_name] = { type: "boolean" }
        required << camel_name
      end
    end

    slots = comp.slots || []
    prop_defs = comp.prop_definitions || {}

    slots.each do |slot|
      slot_name = slot["name"]
      children = (slot["allowed_children"] || []).map { |c| normalize_child_name(c) }.select { |c| component_name_index.key?(c) }

      if children.length == 1
        props[slot_name] = { type: "array", items: { "$ref" => "#/$defs/#{children.first}" } }
        required << slot_name
      elsif children.any?
        props[slot_name] = {
          type: "array",
          items: { anyOf: children.map { |c| { "$ref" => "#/$defs/#{c}" } } }
        }
        required << slot_name
      end
    end

    # Fallback: if no slots but component has slot instances in its tree, add generic children
    if slots.empty? && has_slot?(comp.figma_json, prop_defs)
      props["children"] = { type: "string" }
      required << "children"
    end

    {
      type: "object",
      additionalProperties: false,
      required: required.uniq,
      properties: props
    }
  end

  def variant_enum_values(component_set, prop_name)
    component_set.variants.map { |v|
      v.variant_properties[prop_name.downcase]
    }.compact.uniq
  end

  def eligible_component_sets
    @eligible_component_sets ||= @libraries.flat_map { |lib| lib.component_sets.reject(&:vector?) }
  end

  def eligible_standalone_components
    @eligible_standalone_components ||= @libraries.flat_map { |lib| lib.components.reject(&:vector?) }
  end

  def root_components
    @root_components ||= begin
      roots = eligible_component_sets.select(&:is_root)
      roots += eligible_standalone_components.select(&:is_root)
      roots
    end
  end

  def root_component_names
    @root_component_names ||= root_components.map { |c| to_component_name(c.name) }
  end

  def has_slot?(node, prop_definitions = {})
    return false unless node.is_a?(Hash)

    return true if node["type"] == "SLOT"

    if node["type"] == "INSTANCE"
      ref = node["componentPropertyReferences"]&.dig("mainComponent")
      if ref
        defn = prop_definitions[ref]
        return true if defn&.dig("type") == "INSTANCE_SWAP" && (defn["preferredValues"] || []).any?
      end
    end

    (node["children"] || []).any? { |c| has_slot?(c, prop_definitions) }
  end

  def component_by_name(name)
    component_name_index[name] || component_name_index[to_component_name(name)]
  end

  # Maps to_component_name(cs.name) → component record
  def component_name_index
    @component_name_index ||= begin
      index = {}
      eligible_component_sets.each { |cs| index[to_component_name(cs.name)] = cs }
      eligible_standalone_components.each { |comp| index[to_component_name(comp.name)] = comp }
      index
    end
  end

  # Normalize an allowed_children name to the def key used in the schema
  def normalize_child_name(raw_name)
    return raw_name if component_name_index.key?(raw_name)

    normalized = to_component_name(raw_name)
    return normalized if component_name_index.key?(normalized)

    raw_name
  end

  def reachable_names
    @reachable_names ||= Set.new.tap { |s| collect_reachable(root_component_names, s) }
  end

  def all_components
    result = {}
    component_name_index.each do |name, record|
      next unless reachable_names.include?(name)
      result[name] = record.description.presence || "Component"
    end
    result
  end
end
