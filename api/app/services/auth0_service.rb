class Auth0Service
  def self.domain
    ENV.fetch("AUTH0_DOMAIN")
  end

  def self.audience
    ENV.fetch("AUTH0_AUDIENCE")
  end

  def self.jwks_uri
    "https://#{domain}/.well-known/jwks.json"
  end

  def self.get_jwks
    Rails.cache.fetch("auth0:jwks", :expires_in => 1.hour) do
      JSON.parse(Faraday.get(jwks_uri).body)
    end
  rescue
    {}
  end

  def self.decode_token(token)
    # In E2E test mode, accept simple HMAC-signed test tokens
    if Rails.env.development? || (Rails.env.test? && ENV["E2E_TEST_MODE"] == "true")
      return decode_test_token(token)
    end

    jwks = get_jwks
    return nil if jwks["keys"].blank?

    header = JWT.decode(token, nil, false)[1] rescue nil
    return nil unless header&.dig("kid")

    jwk = jwks["keys"].find { |k| k["kid"] == header["kid"] }
    return nil unless jwk

    public_key = build_rsa_key(jwk)
    JWT.decode(token, public_key, true, {
      :algorithm => "RS256",
      :iss => "https://#{domain}/",
      :verify_iss => true,
      :aud => audience,
      :verify_aud => true
    })[0]
  rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature
    nil
  end

  def self.decode_test_token(token)
    secret = ENV.fetch("E2E_JWT_SECRET", "e2e-test-secret-key")
    JWT.decode(token, secret, true, { algorithm: "HS256" })[0]
  rescue JWT::DecodeError
    nil
  end

  def self.fetch_userinfo(token)
    response = Faraday.get("https://#{domain}/userinfo") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end
    return nil unless response.success?

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  private

  def self.build_rsa_key(jwk)
    n = Base64.urlsafe_decode64(jwk["n"] + "=" * ((4 - jwk["n"].length % 4) % 4))
    e = Base64.urlsafe_decode64(jwk["e"] + "=" * ((4 - jwk["e"].length % 4) % 4))

    key = OpenSSL::PKey::RSA.new
    key.send(:set_key, OpenSSL::BN.new(n, 2), OpenSSL::BN.new(e, 2), nil)
    key
  rescue
    # Fallback ASN.1 construction
    seq = OpenSSL::ASN1::Sequence([
      OpenSSL::ASN1::Integer(OpenSSL::BN.new(n, 2)),
      OpenSSL::ASN1::Integer(OpenSSL::BN.new(e, 2))
    ])
    algorithm = OpenSSL::ASN1::Sequence([
      OpenSSL::ASN1::ObjectId("rsaEncryption"),
      OpenSSL::ASN1::Null.new(nil)
    ])
    OpenSSL::PKey::RSA.new(OpenSSL::ASN1::Sequence([algorithm, OpenSSL::ASN1::BitString(seq.to_der)]).to_der)
  end
end
