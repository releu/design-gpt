class Render < ApplicationRecord
  before_create :set_token

  def set_token
    self.token = SecureRandom.uuid
  end
end
