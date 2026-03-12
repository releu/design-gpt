class Iteration < ApplicationRecord
  belongs_to :design
  belongs_to :render, optional: true
  belongs_to :design_system, optional: true

  before_create :generate_share_code

  private

  def generate_share_code
    loop do
      self.share_code = SecureRandom.alphanumeric(6).downcase
      break unless Iteration.exists?(share_code: share_code)
    end
  end
end
