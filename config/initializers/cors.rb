# frozen_string_literal: true

# CORS (Cross-Origin Resource Sharing) configuration for API access
#
# Who needs CORS?
#   - Expo Go web preview (sends Origin headers, unlike native iOS/Android)
#   - Swagger UI at /api/docs (cross-origin in development)
#   - Future web clients consuming the API directly
#   - Native iOS/Android apps do NOT send Origin headers, so CORS is irrelevant for them
#
# Production note: Set CORS_ALLOWED_ORIGINS env var to a comma-separated list of
# allowed origins (e.g. "https://app.vitt.io,https://vitt.io").
# In development and test, all origins are permitted.

Rails.application.config.middleware.insert_before(0, Rack::Cors) do
  allow do
    if Rails.env.production?
      allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "https://app.vitt.io,https://vitt.io")
                           .split(",")
                           .map(&:strip)
      origins(*allowed_origins)
    else
      # Development and test: allow all origins for ease of iteration
      origins "*"
    end

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"],
      max_age: 86_400 # 24 hours preflight cache
  end
end
