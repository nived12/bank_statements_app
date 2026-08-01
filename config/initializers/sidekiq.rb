# Sidekiq configuration for Railway deployment
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    network_timeout: 5,
    pool_timeout: 5
  }

  # Log level for production
  config.logger.level = Logger::INFO if Rails.env.production?

  # Scheduled jobs — server process only, never the client (see config/schedule.yml).
  config.on(:startup) do
    schedule_file = Rails.root.join("config/schedule.yml")
    next unless File.exist?(schedule_file)

    schedule = YAML.safe_load(ERB.new(File.read(schedule_file)).result, aliases: true) || {}

    # Bang variant drops entries no longer in the file. The STRING key
    # "source" is load-bearing: destroy_removed_jobs only touches jobs whose
    # source is "schedule", and a symbol key leaves them "dynamic", silently
    # making the bang a no-op. Returns a Hash of { name => errors }.
    errors = Sidekiq::Cron::Job.load_from_hash!(schedule, "source" => "schedule")

    errors.each do |name, messages|
      detail = Array(messages).join(", ")
      Rails.logger.error("[sidekiq-cron] #{name}: #{detail}")

      # Report, don't just log: a rejected entry means that job never runs.
      if defined?(Sentry)
        Sentry.capture_message(
          "[sidekiq-cron] schedule entry rejected: #{name}",
          level: :error,
          extra: { job: name, errors: detail }
        )
      end
    end

    if errors.empty?
      Rails.logger.info("[sidekiq-cron] scheduled #{schedule.keys.size} jobs: #{schedule.keys.join(", ")}")
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    network_timeout: 5,
    pool_timeout: 5
  }
end
