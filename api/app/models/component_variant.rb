class ComponentVariant < ApplicationRecord
  belongs_to :component_set

  validates :node_id, presence: true, uniqueness: { scope: :component_set_id }

  scope :default, -> { where(is_default: true) }

  delegate :component_library, :figma_file_key, :figma_file_name, to: :component_set

  def figma_url
    return nil unless figma_file_key && node_id

    encoded_node_id = node_id.tr(":", "-")
    "https://www.figma.com/design/#{figma_file_key}?node-id=#{encoded_node_id}"
  end

  # Parse variant properties from name like "Size=M, State=hover"
  def variant_properties
    return {} unless name.present?

    name.split(",").each_with_object({}) do |part, hash|
      key, value = part.strip.split("=", 2)
      hash[key.strip.downcase] = value&.strip if key.present?
    end
  end
end
