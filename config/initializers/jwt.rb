# frozen_string_literal: true

# JWT Configuration
# This initializer sets up JWT-specific configuration for API authentication

module JwtConfig
  # JWT Secret Key
  # In production, use environment variable (Railway/Heroku)
  # In development/test, use a simple secret for ease of use
  def self.secret_key
    if Rails.env.production?
      # In production, prefer ENV variable, fall back to credentials
      ENV.fetch("JWT_SECRET_KEY") do
        Rails.application.credentials.dig(:jwt, :secret_key) ||
        Rails.application.credentials.secret_key_base
      end
    else
      # In development/test, use a consistent secret
      ENV.fetch("JWT_SECRET_KEY") { "development_jwt_secret_key_change_in_production" }
    end
  end

  # JWT Issuer - identifies who issued the token
  def self.issuer
    "bank_statements_app"
  end

  # JWT Audience - identifies who the token is intended for
  def self.audience
    "bank_statements_app_api"
  end
end
