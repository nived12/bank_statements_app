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

    # Bang variant also destroys cron entries no longer in the file, so a renamed
    # or deleted job stops firing instead of lingering in Redis forever.
    #
    # `"source" => "schedule"` is required and easy to miss: destroy_removed_jobs
    # only touches jobs with that source, and Job#initialize reads the STRING key
    # (`args["source"]`), so a symbol key silently leaves them "dynamic" and makes
    # the bang variant a no-op.
    #
    # Returns a Hash of { job_name => errors }, not an Array.
    errors = Sidekiq::Cron::Job.load_from_hash!(schedule, "source" => "schedule")
    errors.each { |name, messages| Rails.logger.error("[sidekiq-cron] #{name}: #{Array(messages).join(", ")}") }
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    network_timeout: 5,
    pool_timeout: 5
  }
end
