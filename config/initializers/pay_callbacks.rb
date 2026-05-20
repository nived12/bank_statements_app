# frozen_string_literal: true

# Reset the unified AI usage counter when a user converts from trial to a paid subscription.
# Fresh quota ensures trial usage doesn't burn into the first premium billing cycle.
Rails.application.config.after_initialize do
  Pay::Subscription.after_create do |sub|
    next unless sub.status.to_s == "active"

    user = sub.customer&.owner
    next unless user.is_a?(User)

    now = Time.current
    user.quota.update_columns(
      ai_usage_count: 0,
      ai_usage_reset_at: now + 1.month,
      ai_usage_anchor_day: now.day,
      ai_usage_threshold_shown: 0,
      updated_at: now
    )
  end
end
