module AuthHelper
  def auth_headers(user)
    { "Authorization" => "Bearer test_token_for_#{user.auth0_id}" }
  end

  def stub_auth_for(user)
    allow(Auth0Service).to receive(:decode_token).and_return(
      { "sub" => user.auth0_id, "nickname" => user.username, "email" => user.email }
    )
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
