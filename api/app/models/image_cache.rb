class ImageCache < ApplicationRecord
  validates :query, presence: true, uniqueness: true

  def self.search(query)
    normalized = query.to_s.strip.downcase
    cached = find_by(query: normalized)
    return cached.as_result if cached

    result = YandexImages.new.search(query)
    create!(query: normalized, url: result[:url], width: result[:width], height: result[:height])
    result
  rescue ActiveRecord::RecordNotUnique
    find_by!(query: normalized).as_result
  end

  def as_result
    { url: url, width: width, height: height }
  end
end
