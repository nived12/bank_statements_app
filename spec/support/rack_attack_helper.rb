# frozen_string_literal: true

# Rack::Attack helper for request specs
# This ensures rate limiting doesn't interfere with test execution
RSpec.configure do |config|
  config.before(:each, type: :request) do
    # Clear Rack::Attack cache before each request spec to prevent rate limiting
    Rack::Attack.cache.store.clear
  end
end
