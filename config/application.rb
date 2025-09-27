require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BankStatementsApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Security: Filter sensitive parameters from logs
    config.filter_parameters += [:password, :password_confirmation, :current_password, :new_password]

    # Internationalization configuration
    config.i18n.available_locales = [ :en, :es ]
    config.i18n.default_locale = :es
    config.i18n.fallbacks = true

    # Error handling configuration
    config.exceptions_app = self.routes

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Handle autoload_lib more carefully to avoid frozen array issues in Rails 8.0.2
    if defined?(config.autoload_lib)
      begin
        config.autoload_lib(ignore: %w[assets tasks])
      rescue FrozenError => e
        Rails.logger.warn "Autoload lib failed: #{e.message}, using alternative approach"
        # Add lib to autoload paths manually if needed
        lib_path = Rails.root.join("lib")
        unless config.autoload_paths.include?(lib_path)
          config.autoload_paths = config.autoload_paths.dup
          config.autoload_paths << lib_path
        end
      end
    else
      # Fallback for older Rails versions
      config.autoload_paths << Rails.root.join("lib")
    end

    config.active_job.queue_adapter = :sidekiq  # Use Sidekiq for background job processing

    # Environment-specific credential configuration
    config.after_initialize do
      if Rails.env.test?
        # Use test credentials for test environment
        ENV["RAILS_MASTER_KEY"] = File.read(Rails.root.join("config", "credentials", "test.key")).strip
      elsif Rails.env.development?
        # Use development credentials for development environment
        ENV["RAILS_MASTER_KEY"] = File.read(Rails.root.join("config", "credentials", "development.key")).strip
      end
      # Production will use the default master.key
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Set timezone to be detected from system or default to UTC
    # The actual timezone will be set per-request based on user's browser
    config.time_zone = "UTC"
    # config.eager_load_paths << Rails.root.join("extras")

    # RSpec
    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: true,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false,
                       controller_specs: true,
                       request_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
