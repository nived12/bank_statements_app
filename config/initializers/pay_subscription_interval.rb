# frozen_string_literal: true

# Pay::Subscription lives in the gem, so the extension is mixed in here rather than
# reopened in app/models. to_prepare (not after_initialize) so it survives dev reloads.
Rails.application.config.to_prepare do
  Pay::Subscription.include PaySubscriptionInterval
end
