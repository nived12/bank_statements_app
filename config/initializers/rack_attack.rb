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
  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "RateLimit-Limit" => match_data[:limit].to_s,
      "RateLimit-Remaining" => "0",
      "RateLimit-Reset" => (now + (match_data[:period] - now % match_data[:period])).to_s,
      "Content-Type" => "text/html"
    }

    # Return user-friendly HTML response
    [429, headers, [<<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Too Many Requests</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            background: #f8fafc;
          }
          .container {
            text-align: center;
            padding: 2rem;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-width: 500px;
          }
          h1 {
            color: #dc2626;
            margin: 0 0 1rem 0;
          }
          p {
            color: #64748b;
            line-height: 1.6;
          }
          .retry-info {
            background: #fef3c7;
            padding: 1rem;
            border-radius: 4px;
            margin-top: 1.5rem;
            font-size: 0.9rem;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Too Many Requests</h1>
          <p>You've made too many requests. Please wait a moment before trying again.</p>
          <div class="retry-info">
            <strong>Rate limit exceeded.</strong><br>
            Try again later.
          </div>
        </div>
      </body>
      </html>
    HTML
    ]]
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
