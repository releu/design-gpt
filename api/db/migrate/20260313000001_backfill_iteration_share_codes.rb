class BackfillIterationShareCodes < ActiveRecord::Migration[8.0]
  def up
    Iteration.where(share_code: nil).find_each do |i|
      loop do
        code = SecureRandom.alphanumeric(6).downcase
        unless Iteration.exists?(share_code: code)
          i.update_column(:share_code, code)
          break
        end
      end
    end
  end

  def down
    # no-op
  end
end
