
# OmniAuth configuration
# Only configure OmniAuth if credentials are present (they won't be during Docker build)
client_id     = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence     || (Rails.env.test? ? "test_client_id" : nil)
client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence || (Rails.env.test? ? "test_client_secret" : nil)

if client_id && client_secret
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, client_id, client_secret, { scope: "email,profile" }
  end

  # Pin full_host in production so callbacks always go to app.vitt.io.
  # In other environments let OmniAuth derive the host from the request.
  if Rails.env.production?
    OmniAuth.config.full_host = Rails.configuration.x.app_domain
  end

  OmniAuth.config.allowed_request_methods = [ :post ]
  OmniAuth.config.silence_get_warning = true
  OmniAuth.config.request_validation_phase = false

  OmniAuth.config.on_failure = proc do |env|
    SessionsController.action(:oauth_failure).call(env)
  end
else
  Rails.logger.warn "OAuth credentials not found - OmniAuth will not be configured. This is expected during asset precompilation."
end
