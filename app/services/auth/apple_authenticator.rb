# frozen_string_literal: true

module Auth
  # Verifies an Apple Sign In identity token against Apple's JWKS and
  # returns (creating if needed) the matching User. Apple sends the user's
  # name and email only on the FIRST authorization — subsequent sign-ins
  # carry only the `sub` claim, so we persist whatever arrives the first time.
  class AppleAuthenticator < ApplicationService
    APPLE_ISSUER = "https://appleid.apple.com"
    APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
    JWKS_CACHE_KEY = "auth/apple_jwks"
    JWKS_CACHE_TTL = 1.hour
    AUDIENCE = ENV.fetch("APPLE_CLIENT_ID", "io.vitt.app")

    def initialize(identity_token:, first_name: nil, last_name: nil, email: nil)
      super()
      @identity_token = identity_token
      @first_name = first_name.presence
      @last_name = last_name.presence
      @email = email.presence&.downcase
    end

    def call
      return failure("Missing identity_token") if @identity_token.blank?

      payload = decode_and_verify!
      return failure("Invalid Apple identity token") unless payload

      user = upsert_user(payload)
      success(user)
    rescue JWT::DecodeError => e
      Rails.logger.warn("[AppleAuth] JWT decode failed: #{e.message}")
      failure("Invalid Apple identity token")
    end

    private

    def decode_and_verify!
      jwks_loader = ->(options) { jwks(force_refresh: options[:invalidate]) }

      payload, _header = JWT.decode(
        @identity_token,
        nil,
        true,
        algorithms: ["RS256"],
        iss: APPLE_ISSUER,
        verify_iss: true,
        aud: AUDIENCE,
        verify_aud: true,
        verify_expiration: true,
        jwks: jwks_loader
      )
      payload
    end

    def jwks(force_refresh: false)
      Rails.cache.delete(JWKS_CACHE_KEY) if force_refresh
      Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: JWKS_CACHE_TTL) do
        response = Net::HTTP.get_response(URI(APPLE_JWKS_URL))
        raise JWT::DecodeError, "Apple JWKS unavailable: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end

    def upsert_user(payload)
      uid = payload["sub"]
      token_email = payload["email"]&.downcase

      existing = User.kept.find_by(provider: "apple", uid: uid)
      return existing if existing

      # Link by email if a non-OAuth account already exists with this email
      email = @email || token_email
      existing_by_email = User.kept.find_by(email: email) if email
      if existing_by_email
        existing_by_email.update!(
          provider: "apple",
          uid: uid,
          first_name: @first_name || existing_by_email.first_name,
          last_name: @last_name || existing_by_email.last_name,
          confirmed_at: existing_by_email.confirmed_at || Time.current
        )
        return existing_by_email
      end

      User.create!(
        email: email,
        provider: "apple",
        uid: uid,
        first_name: @first_name || email&.split("@")&.first&.capitalize || "Apple",
        last_name: @last_name || "User",
        password: SecureRandom.hex(16),
        confirmed_at: Time.current
      )
    end
  end
end
