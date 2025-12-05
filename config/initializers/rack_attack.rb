# Rack::Attack configuration for rate limiting
# See https://github.com/rack/rack-attack for more info

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache store for tracking request counts
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

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

  ### Custom Throttle Response ###
  # Customize the response when rate limit is exceeded
  # Returns a redirect with flash message instead of plain 429 response
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])
    minutes = (retry_after / 60.0).ceil

    # Set flash message in session
    # Use I18n with fallback to spanish if translation is not available
    locale = request.env["rack.session"]&.dig("locale") || :es
    message = I18n.t("errors.rate_limit_exceeded", minutes: minutes, locale: locale, default: "Límite de solicitudes excedido. Por favor intenta de nuevo en #{minutes} minutos.")

    # Store flash message in session using Rails flash structure
    request.env["rack.session"]["flash"] = { "flashes" => { "alert" => message }, "discard" => [] }

    # Get referer or fallback to root
    referer = request.env["HTTP_REFERER"] || "/"

    # Return 302 redirect to referer
    [302, { "Location" => referer, "Content-Type" => "text/html" }, ["Redirecting..."]]
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
