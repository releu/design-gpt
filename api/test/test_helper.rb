ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Load a Figma API mock JSON fixture
    def load_figma_fixture(name)
      path = Rails.root.join("test", "fixtures", "files", "figma_#{name}.json")
      ::JSON.parse(File.read(path))
    end
  end
end

# Helper module for controller tests that need authentication
module AuthHelper
  def sign_in_as(user)
    # Stub Auth0Service.decode_token to return a payload matching the user
    Auth0Service.stub(:decode_token, ->(_token) {
      { "sub" => user.auth0_id, "nickname" => user.username, "email" => user.email }
    }) do
      yield
    end
  end

  def auth_headers(user)
    { "Authorization" => "Bearer test_token_for_#{user.auth0_id}" }
  end
end

class ActionDispatch::IntegrationTest
  include AuthHelper
end
