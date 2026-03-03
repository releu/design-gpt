namespace :e2e do
  desc "Reset test database and load only users fixture for E2E tests"
  task setup: :environment do
    abort("Only in test!") unless Rails.env.test?

    require "active_record/fixtures"
    fixtures_dir = Rails.root.join("test/fixtures")
    ActiveRecord::FixtureSet.reset_cache
    ActiveRecord::FixtureSet.create_fixtures(fixtures_dir, ["users"])

    puts "E2E fixtures loaded successfully"
  end
end
