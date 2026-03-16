class Iteration < ApplicationRecord
  belongs_to :design
  belongs_to :render, optional: true
  belongs_to :design_system, optional: true

  before_create :generate_share_code

  private

  def generate_share_code
    prefix = Rails.env.development? ? "dev-" : ""
    suffix_length = Rails.env.development? ? 6 : 6
    loop do
      self.share_code = "#{prefix}#{SecureRandom.alphanumeric(suffix_length).downcase}"
      break unless Iteration.exists?(share_code: share_code)
    end
  end
end
