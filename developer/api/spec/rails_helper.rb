require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

# Allow localhost connections (for Ferrum/Chrome in tests) but block external
WebMock.disable_net_connect!(allow_localhost: true)

# Load support files
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Use test/fixtures (shared with minitest)
  config.fixture_paths = [Rails.root.join("test/fixtures")]
  config.global_fixtures = :all

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ActiveJob::TestHelper
end
