class ComponentSet < ApplicationRecord
  belongs_to :figma_file
  has_many :variants, class_name: "ComponentVariant", dependent: :destroy
  has_many :figma_assets, dependent: :destroy
  has_one :pipeline_review, dependent: :destroy

  validates :node_id, presence: true, uniqueness: { scope: :figma_file_id }

  STATUSES = %w[pending imported error skipped].freeze
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  VECTOR_TYPES = %w[VECTOR BOOLEAN_OPERATION ELLIPSE RECTANGLE LINE STAR POLYGON].freeze
  CONTAINER_TYPES = %w[COMPONENT COMPONENT_SET FRAME GROUP].freeze

  def figma_url
    return nil unless figma_file_key && node_id

    encoded_node_id = node_id.tr(":", "-")
    "https://www.figma.com/design/#{figma_file_key}?node-id=#{encoded_node_id}"
  end

  def default_variant
    variants.find_by(is_default: true) || variants.first
  end

  def has_warnings?
    validation_warnings.present? && validation_warnings.any?
  end

  scope :without_warnings, -> {
    where("validation_warnings IS NULL OR validation_warnings = '[]'")
  }

  # Detect if this component set contains only vector shapes
  def vector?
    return false unless default_variant&.figma_json.present?

    contains_only_vectors?(default_variant.figma_json)
  end

  private

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
end
