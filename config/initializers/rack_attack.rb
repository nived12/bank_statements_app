# Rack::Attack configuration for rate limiting
# See https://github.com/rack/rack-attack for more info

class Rack::Attack
  ### Configure Cache ###
  # Use Rails.cache (Redis in production) so rate limit counters are shared
  # across all Puma workers. MemoryStore is per-process and would divide
  # effective limits by the number of workers.
  Rack::Attack.cache.store = Rails.cache

  ### Throttle (Rate Limit) ###

  # Throttle email confirmation resend requests by IP address
  # Limit: 5 requests per hour per IP
  throttle("email_confirmations/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/email_confirmations" && req.post?
      req.ip
    end
  end

  # Throttle email confirmation resend requests by email address
  # Limit: 3 requests per hour per email
  throttle("email_confirmations/email", limit: 3, period: 1.hour) do |req|
    if req.path == "/email_confirmations" && req.post?
      # Extract email from params
      req.params["email"]&.strip&.downcase
    end
  end

  # Throttle password reset requests by IP address
  # Limit: 5 requests per hour per IP
  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/password_resets" && req.post?
      req.ip
    end
  end

  # Throttle password reset requests by email address
  # Limit: 3 requests per hour per email
  throttle("password_resets/email", limit: 3, period: 1.hour) do |req|
    if req.path == "/password_resets" && req.post?
      req.params["email"]&.strip&.downcase
    end
  end

  # Throttle login attempts by IP address
  # Limit: 10 attempts per hour per IP
  throttle("sessions/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/session" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email address
  # Limit: 5 attempts per hour per email
  throttle("sessions/email", limit: 5, period: 1.hour) do |req|
    if req.path == "/session" && req.post?
      req.params["email"]&.strip&.downcase
    end
  end

  ### API Rate Limiting ###

  # Throttle API login attempts by IP address
  # Limit: 10 attempts per hour per IP
  throttle("api/login/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/api/v1/login" && req.post?
      req.ip
    end
  end

  # Throttle API login attempts by email address
  # Limit: 5 attempts per hour per email
  # Note: For JSON requests, this relies on IP throttling since reading the body
  # in the throttle block can interfere with strong parameters parsing
  throttle("api/login/email", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/v1/login" && req.post?
      # Only extract email from form params, not JSON body
      # JSON body reading can cause issues with strong parameters
      req.params.dig("user", "email")&.strip&.downcase if req.params["user"]
    end
  end

  # Throttle API signup attempts by IP address
  # Limit: 5 signups per hour per IP (stricter than login)
  throttle("api/signup/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/v1/signup" && req.post?
      req.ip
    end
  end

  # Throttle API refresh token requests by IP
  # Limit: 20 per hour per IP (more lenient as users may refresh frequently)
  throttle("api/refresh/ip", limit: 20, period: 1.hour) do |req|
    if req.path == "/api/v1/refresh" && req.post?
      req.ip
    end
  end

  # Throttle API password reset requests by IP address
  # Limit: 5 requests per hour per IP
  throttle("api/password_resets/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/v1/password_resets" && req.post?
      req.ip
    end
  end

  # Throttle API email confirmation resend by IP address
  # Limit: 5 requests per hour per IP
  throttle("api/email_confirmations/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/v1/email_confirmations" && req.post?
      req.ip
    end
  end

  # Throttle file upload requests by IP address
  # Limit: 20 uploads per hour per IP (file uploads are resource-intensive)
  throttle("api/statement_files/ip", limit: 20, period: 1.hour) do |req|
    if req.path == "/api/v1/statement_files" && req.post?
      req.ip
    end
  end

  # Throttle file upload requests by authenticated user
  # Limit: 50 uploads per hour per user (more lenient for authenticated users)
  throttle("api/statement_files/user", limit: 50, period: 1.hour) do |req|
    if req.path == "/api/v1/statement_files" && req.post?
      # Extract user ID from JWT token if present
      auth_header = req.env["HTTP_AUTHORIZATION"]
      if auth_header&.start_with?("Bearer ")
        token = auth_header.split(" ").last
        begin
          # Decode JWT to get user ID (without verification for rate limiting purposes)
          payload = JWT.decode(token, nil, false).first
          "user:#{payload["user_id"]}" if payload["user_id"]
        rescue JWT::DecodeError
          nil
        end
      end
    end
  end

  # General API throttle for all authenticated API requests
  # Limit: 100 requests per minute per authenticated user
  # Applies to all /api/v1/* endpoints to prevent polling abuse
  throttle("api/general/user", limit: 100, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/")
      auth_header = req.env["HTTP_AUTHORIZATION"]
      if auth_header&.start_with?("Bearer ")
        token = auth_header.split(" ").last
        begin
          payload = JWT.decode(token, nil, false).first
          "api_user:#{payload["user_id"]}" if payload["user_id"]
        rescue JWT::DecodeError
          nil
        end
      end
    end
  end

  ### Custom Throttle Response ###
  # Customize the response when rate limit is exceeded
  # Returns JSON for API requests, redirect for web requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])
    minutes = (retry_after / 60.0).ceil

    # Check if this is an API request
    if request.path.start_with?("/api/")
      # Return JSON error response for API
      [
        429,
        {
          "Content-Type" => "application/json",
          "Retry-After" => retry_after.to_s
        },
        [{
          error: {
            message: "Rate limit exceeded. Please try again in #{minutes} minutes.",
            code: "RATE_LIMIT_EXCEEDED",
            retry_after: retry_after
          }
        }.to_json]
      ]
    else
      # Web request - return redirect with flash message
      locale = request.env["rack.session"]&.dig("locale") || :es
      message = I18n.t(
        "errors.rate_limit_exceeded", minutes: minutes, locale: locale,
        default: "Límite de solicitudes excedido. Por favor intenta de nuevo en #{minutes} minutos."
      )

      # Store flash message in session using Rails flash structure
      request.env["rack.session"]["flash"] = { "flashes" => { "alert" => message }, "discard" => [] }

      # Get referer or fallback to root
      referer = request.env["HTTP_REFERER"] || "/"

      # Return 302 redirect to referer
      [302, { "Location" => referer, "Content-Type" => "text/html" }, ["Redirecting..."]]
    end
  end

  ### Logging ###
  # Log blocked requests in production
  ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
    req = payload[:request]
    if [:throttle].include?(req.env["rack.attack.match_type"])
      Rails.logger.info "[Rack::Attack] Throttled request from #{req.ip} to #{req.path}"
    end
  end
end
