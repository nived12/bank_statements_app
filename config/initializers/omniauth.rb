
# OmniAuth configuration
Rails.application.config.middleware.use OmniAuth::Builder do
  client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"]
  client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"]

  if client_id.present? && client_secret.present?
    provider :google_oauth2, client_id, client_secret, {
      scope: "email,profile"
    }
  else
    Rails.logger.warn "OAuth configuration missing: client_id=#{client_id.present? ? "SET" : "MISSING"}, client_secret=#{client_secret.present? ? "SET" : "MISSING"}"
  end
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
