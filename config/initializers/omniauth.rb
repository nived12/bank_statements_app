
# OmniAuth configuration
# Only configure OmniAuth if credentials are present (they won't be during Docker build)
if ENV["GOOGLE_OAUTH_CLIENT_ID"].present? && ENV["GOOGLE_OAUTH_CLIENT_SECRET"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, ENV["GOOGLE_OAUTH_CLIENT_ID"], ENV["GOOGLE_OAUTH_CLIENT_SECRET"], {
      scope: "email,profile"
    }
  end

  # Ensure OAuth callbacks always use app.vitt.io in production
  OmniAuth.config.full_host = lambda do |_env|
    ENV.fetch("APP_DOMAIN", "https://app.vitt.io") if Rails.env.production?
  end

  # Configure OmniAuth CSRF protection
  OmniAuth.config.allowed_request_methods = [ :post ]
  OmniAuth.config.silence_get_warning = true

  # Disable CSRF protection for OAuth requests
  OmniAuth.config.request_validation_phase = false

  # Handle OAuth failures
  OmniAuth.config.on_failure = proc do |env|
    SessionsController.action(:oauth_failure).call(env)
  end

  # Enable OmniAuth test mode in development
  if Rails.env.development?
    OmniAuth.config.test_mode = false
  end
else
  Rails.logger.warn "OAuth credentials not found - OmniAuth will not be configured. This is expected during asset precompilation."
end
