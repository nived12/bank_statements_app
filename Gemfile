source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Environment variables
gem "dotenv-rails"

# HTTP client for API requests
gem "httparty"

# Google Cloud Storage for Active Storage
gem "google-cloud-storage", "~> 1.11", require: false

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# JWT for API authentication
gem "jwt"

# OAuth authentication
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use simpler adapters for Railway deployment
# gem "solid_cache"  # Using default cache for Railway
# gem "solid_queue"  # Using sidekiq for Railway
# gem "solid_cable"  # Using async adapter for Railway

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing"

# Background jobs
gem "sidekiq"  # For background job processing
gem "connection_pool", "~> 2.5.4"  # Fix Ruby 3.3 compatibility issue

# Email delivery
gem "resend"  # Transactional email service

# Rate limiting
gem "rack-attack"  # Protect against abuse and bad actors

# CORS support for mobile and cross-origin API access
gem "rack-cors"

# Pagination
gem "pagy"

# Payments and subscriptions (Stripe, manual plans)
gem "pay"
gem "stripe"

# API documentation with OpenAPI/Swagger
gem "rswag-api"
gem "rswag-ui"

# PDF parsing
gem "pdf-reader"
gem "combine_pdf"

# PDF generation
gem "prawn"
gem "prawn-table"

# OCR for scanned PDFs
gem "rtesseract"        # Requires system Tesseract installed

# Image processing
gem "mini_magick"

# Icon library
gem "rails_icons"

# Soft delete/archiving
gem "discard", "~> 1.3"

# Web push notifications (VAPID)
gem "webpush", "~> 1.1"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "rswag-specs"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "database_cleaner-active_record"
  gem "webmock"  # HTTP request stubbing for specs
end
