require "rails_helper"

RSpec.describe Auth0Service do
  describe ".decode_token" do
    let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:kid) { "test-key-id" }

    let(:jwks) do
      n = Base64.urlsafe_encode64(rsa_key.n.to_s(2), padding: false)
      e = Base64.urlsafe_encode64(rsa_key.e.to_s(2), padding: false)
      {
        "keys" => [{
          "kty" => "RSA",
          "kid" => kid,
          "n" => n,
          "e" => e,
          "alg" => "RS256",
          "use" => "sig"
        }]
      }
    end

    before do
      allow(Auth0Service).to receive(:get_jwks).and_return(jwks)
      allow(Auth0Service).to receive(:domain).and_return("auth.example.com")
      allow(Auth0Service).to receive(:audience).and_return("test-audience")
    end

    it "decodes a valid token" do
      token = JWT.encode(
        { "sub" => "auth0|123", "iss" => "https://auth.example.com/", "aud" => "test-audience", "exp" => 1.hour.from_now.to_i },
        rsa_key,
        "RS256",
        { kid: kid }
      )

      payload = Auth0Service.decode_token(token)
      expect(payload["sub"]).to eq("auth0|123")
    end

    it "returns nil for expired token" do
      token = JWT.encode(
        { "sub" => "auth0|123", "iss" => "https://auth.example.com/", "aud" => "test-audience", "exp" => 1.hour.ago.to_i },
        rsa_key,
        "RS256",
        { kid: kid }
      )

      expect(Auth0Service.decode_token(token)).to be_nil
    end

    it "returns nil for invalid token" do
      expect(Auth0Service.decode_token("garbage")).to be_nil
    end

    it "returns nil when JWKS has no keys" do
      allow(Auth0Service).to receive(:get_jwks).and_return({ "keys" => [] })
      expect(Auth0Service.decode_token("anything")).to be_nil
    end
  end
end
