# frozen_string_literal: true

# Subscription validation: local trial or active Pay subscription (Stripe or manual).
# Reusable for any gated feature. subscription_access_result returns
# { allowed:, reason:, message: } for 403/flash; pass i18n_scope for feature-specific messages.
module SubscriptionAccess
  extend ActiveSupport::Concern

  included do
    after_create :set_trial_ends_at
  end

  def subscription_access_result(i18n_scope: "statement_files.upload_denied")
    return { allowed: true } if active_trial?
    return { allowed: true } if active_paid_subscription?

    reason = subscription_denied_reason
    message = I18n.t("#{i18n_scope}.#{reason}")
    { allowed: false, reason: reason, message: message }
  end

  private

  def active_trial?
    trial_ends_at.present? && trial_ends_at > Time.current
  end

  def active_paid_subscription?
    pay_subscriptions.any? { |sub| paid_subscription_allows_access?(sub) }
  end

  def paid_subscription_allows_access?(sub)
    return false unless self.class.paid_plan_names.include?(sub.name.to_s)
    return false if sub.ends_at.present? && sub.ends_at <= Time.current

    case sub.status.to_s
    when "active" then true
    when "trialing" then sub.trial_ends_at.present? && sub.trial_ends_at > Time.current
    else false
    end
  end

  def subscription_denied_reason
    if pay_subscriptions.any? { |s| s.status.to_s == "past_due" && self.class.paid_plan_names.include?(s.name.to_s) }
      :payment_failed
    elsif trial_ends_at.present?
      :trial_ended
    else
      :subscription_required
    end
  end

  def set_trial_ends_at
    trial_days = ENV.fetch("TRIAL_DURATION_DAYS", 30).to_i
    update_column(:trial_ends_at, trial_days.days.from_now)
  end
end
