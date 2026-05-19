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

  # Reset AI usage counter when a premium subscription is created so a user
  # returning after cancellation gets a clean slate rather than an instant lock.
  Pay::Subscription.after_create_commit do
    owner = customer&.owner
    owner.update_column(:ai_usage_count, 0) if owner.respond_to?(:ai_usage_count)
  end
end
