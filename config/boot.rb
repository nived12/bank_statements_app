ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Load environment variables from .env file BEFORE anything else (only in development/test)
if ENV["RAILS_ENV"] == "development" || ENV["RAILS_ENV"] == "test" || ENV["RAILS_ENV"].nil?
  require "dotenv/load"
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
