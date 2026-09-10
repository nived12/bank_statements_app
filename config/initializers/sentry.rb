# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production staging]
  config.traces_sample_rate = 0.1
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  # Scanners send conflicting Client-IP / X-Forwarded-For headers, which RemoteIp
  # raises on before any controller runs: 528 events in 12 days, none actionable.
  # += not =, or this drops the Rails defaults sentry-rails already set.
  # If a legitimate proxy ever sets both headers this would hide real users
  # getting 400s, and the fix then is trusted_proxies, not widening this list.
  config.excluded_exceptions += ["ActionDispatch::RemoteIp::IpSpoofAttackError"]

  # Strip sensitive fields before sending to Sentry
  config.before_send = lambda do |event, hint|
    # Drop benign Sidekiq fetch-loop blips: BRPOP read timeouts caused by brief
    # stalls on Railway's private network. Sidekiq auto-reconnects and no jobs
    # are lost, so these are noise. Any Redis error elsewhere still reaches us.
    ex = hint[:exception]
    if ex.is_a?(RedisClient::ReadTimeoutError) &&
       ex.backtrace&.any? { |line| line.include?("sidekiq/fetch") }
      return nil
    end

    event.request&.data&.delete("password")
    event.request&.data&.delete("password_confirmation")
    event.request&.data&.delete("current_password")
    # Strip Authorization header (JWT tokens)
    event.request&.headers&.delete("Authorization")
    event
  end
end
