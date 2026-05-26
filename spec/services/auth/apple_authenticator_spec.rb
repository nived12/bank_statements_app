# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::AppleAuthenticator do
  # Generate an RSA keypair and matching JWKS so we can sign tokens like Apple does,
  # then stub the JWKS loader to return our public key.
  let(:rsa_private) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "test-key-id" }
  let(:jwk) { JWT::JWK.new(rsa_private.public_key, kid: kid, use: "sig", alg: "RS256") }
  let(:jwks) { { "keys" => [jwk.export] } }

  let(:apple_sub) { "001234.abcdef1234567890.0123" }
  let(:token_email) { "user@privaterelay.appleid.com" }
  let(:audience) { Auth::AppleAuthenticator::AUDIENCE }

  def build_token(payload_overrides = {}, header_overrides = {})
    payload = {
      iss: Auth::AppleAuthenticator::APPLE_ISSUER,
      aud: audience,
      sub: apple_sub,
      email: token_email,
      iat: Time.current.to_i,
      exp: 5.minutes.from_now.to_i
    }.merge(payload_overrides)
    headers = { kid: kid, alg: "RS256" }.merge(header_overrides)
    JWT.encode(payload, rsa_private, "RS256", headers)
  end

  before do
    Rails.cache.clear
    allow_any_instance_of(Auth::AppleAuthenticator).to receive(:jwks).and_return(jwks)
  end

  describe "#call" do
    context "with a valid first-time identity token" do
      it "creates a new user with provider apple" do
        token = build_token

        expect {
          @result = described_class.call(
            identity_token: token,
            first_name: "Juan",
            last_name: "García",
            email: token_email
          )
        }.to change(User, :count).by(1)

        expect(@result).to be_success
        user = @result.payload
        expect(user.provider).to eq("apple")
        expect(user.uid).to eq(apple_sub)
        expect(user.first_name).to eq("Juan")
        expect(user.last_name).to eq("García")
        expect(user.confirmed_at).to be_present
      end
    end

    context "with a returning user (no name in subsequent sign-in)" do
      it "returns the existing user without changing names" do
        existing = create(:user, provider: "apple", uid: apple_sub, first_name: "Juan", last_name: "García")
        token = build_token

        expect {
          @result = described_class.call(identity_token: token)
        }.not_to change(User, :count)

        expect(@result).to be_success
        expect(@result.payload.id).to eq(existing.id)
        expect(@result.payload.first_name).to eq("Juan")
      end
    end

    context "with an existing email-based account" do
      it "links the apple identity to the existing user" do
        existing = create(:user, email: "linkme@example.com")
        token = build_token(email: "linkme@example.com")

        result = described_class.call(identity_token: token, email: "linkme@example.com")

        expect(result).to be_success
        expect(result.payload.id).to eq(existing.id)
        expect(result.payload.reload.provider).to eq("apple")
        expect(result.payload.uid).to eq(apple_sub)
      end
    end

    context "with a token signed by a different key" do
      it "fails verification" do
        other_key = OpenSSL::PKey::RSA.generate(2048)
        payload = { iss: Auth::AppleAuthenticator::APPLE_ISSUER, aud: audience, sub: apple_sub, exp: 5.minutes.from_now.to_i }
        bad_token = JWT.encode(payload, other_key, "RS256", { kid: kid })

        result = described_class.call(identity_token: bad_token)
        expect(result).to be_failure
      end
    end

    context "with a wrong audience" do
      it "fails verification" do
        token = build_token(aud: "com.evil.app")
        result = described_class.call(identity_token: token)
        expect(result).to be_failure
      end
    end

    context "with an expired token" do
      it "fails verification" do
        token = build_token(exp: 5.minutes.ago.to_i)
        result = described_class.call(identity_token: token)
        expect(result).to be_failure
      end
    end

    context "with no identity_token" do
      it "fails fast" do
        result = described_class.call(identity_token: nil)
        expect(result).to be_failure
        expect(result.errors.full_messages.first).to include("Missing")
      end
    end

  end
end
