class Component < ApplicationRecord
  belongs_to :component_library
  has_many :figma_assets, dependent: :destroy

  VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
  CONTAINER_TYPES = %w[COMPONENT COMPONENT_SET FRAME GROUP].freeze

  STATUSES = %w[pending imported error skipped].freeze
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :imported, -> { where(status: "imported") }

  # Detect if component contains only vector shapes
  def vector?
    return false unless figma_json.present?
    contains_only_vectors?(figma_json)
  end

  def figma_url
    return nil unless figma_file_key && node_id

    encoded_node_id = node_id.tr(":", "-")
    file_slug = figma_file_name.present? ? "/#{slugify(figma_file_name)}" : ""

    "https://www.figma.com/design/#{figma_file_key}#{file_slug}?node-id=#{encoded_node_id}"
  end

  # Collect all INSTANCE componentIds referenced in this component's figma_json
  def instance_references
    collect_instance_ids(figma_json)
  end

  private

  def collect_instance_ids(node, ids = [])
    return ids unless node.is_a?(Hash)

    if node["type"] == "INSTANCE" && node["componentId"]
      ids << node["componentId"]
    end

    (node["children"] || []).each do |child|
      collect_instance_ids(child, ids)
    end

    ids.uniq
  end

  def contains_only_vectors?(node)
    return false unless node.is_a?(Hash)

    type = node["type"]

    return true if VECTOR_TYPES.include?(type)

    if CONTAINER_TYPES.include?(type)
      children = node["children"] || []
      return false if children.empty?
      return children.all? { |child| contains_only_vectors?(child) }
    end

    false
  end

  def slugify(name)
    URI.encode_www_form_component(name).gsub("+", "%20")
  end
end
