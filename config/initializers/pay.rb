# frozen_string_literal: true

Rails.configuration.to_prepare do
  Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", nil)

  Pay.setup do |config|
    config.enabled_processors = [:stripe]
    config.automount_routes = true
    config.routes_path = "/pay"
    config.default_product_name = "premium"
    config.default_plan_name = "premium"
  end
end
