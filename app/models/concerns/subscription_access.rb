# frozen_string_literal: true

# Subscription validation: local trial, active Pay subscription (Stripe or manual),
# or a live App Store entitlement.
# Reusable for any gated feature. subscription_access_result returns
# { allowed:, reason:, message: } for 403/flash; pass i18n_scope for feature-specific messages.
module SubscriptionAccess
  extend ActiveSupport::Concern

  included do
    after_create :set_trial_ends_at
  end

  def self.free_tier_statement_files
    ENV.fetch("FREE_TIER_STATEMENT_FILES", 12).to_i
  end

  def self.free_tier_ai_calls
    ENV.fetch("FREE_TIER_AI_CALLS", 15).to_i
  end

  def self.premium_monthly_ai_calls
    ENV.fetch("PREMIUM_MONTHLY_AI_CALLS", 500).to_i
  end

  def subscription_access_result(i18n_scope: "statement_files.upload_denied")
    return { allowed: true } if active_paid_subscription?

    if active_trial?
      if statement_files_count >= SubscriptionAccess.free_tier_statement_files
        return { allowed: false, reason: :upload_limit_reached,
                 message: I18n.t(
                   "#{i18n_scope}.upload_limit_reached",
                   limit: SubscriptionAccess.free_tier_statement_files
                 ) }
      end
      return { allowed: true }
    end

    reason = subscription_denied_reason
    message = I18n.t("#{i18n_scope}.#{reason}")
    { allowed: false, reason: reason, message: message }
  end

  # Unified AI access gate — covers voice, camera, recurring suggestions, and assistant.
  # Trial: one-time pool (FREE_TIER_AI_CALLS). Premium: monthly resetting budget (PREMIUM_MONTHLY_AI_CALLS).
  def ai_access_result
    return { allowed: false, reason: :subscription_required } unless active_paid_subscription? || active_trial?

    Assistant::UsageMeter.new(self).access_result
  end

  # Back-compat alias — callers of assistant_access_result get the same unified gate.
  def assistant_access_result
    ai_access_result
  end

  def active_trial?
    trial_ends_at.present? && trial_ends_at > Time.current
  end

  def active_paid_subscription?
    pay_subscriptions.any? { |sub| paid_subscription_allows_access?(sub) } || active_apple_subscription?
  end

  # App Store subscribers have no Pay::Subscription — Apple bills them and the
  # RevenueCat webhook keeps the entitlement current.
  def active_apple_subscription?
    apple_premium_subscription&.active? || false
  end

  def current_paid_subscription
    pay_subscriptions.find { |sub| paid_subscription_allows_access?(sub) }
  end

  # Whichever record is actually billing this user. Stripe and Apple both answer
  # billing_interval / billing_amount_cents / billing_currency, so every caller asks
  # the user once instead of branching on the processor — the drift that produced
  # the advertised-vs-charged mismatch fixed in b984919 and 1e3de3d.
  #
  # Both associations are cached per instance, so the three readers below cost no
  # extra queries. Loops over users should includes(:pay_subscriptions,
  # :apple_premium_subscription).
  def billing_record
    current_paid_subscription || (apple_premium_subscription if active_apple_subscription?)
  end

  def billing_interval
    billing_record&.billing_interval
  end

  # What they are actually charged, never a configured list price — a subscriber on a
  # retired price is not paying today's number.
  def billing_amount_cents
    billing_record&.billing_amount_cents
  end

  def billing_currency
    billing_record&.billing_currency
  end

  # Who bills them. Drives the asymmetric messaging: the web may name Apple and link
  # to it, iOS must not mention the web (App Store Guideline 3.1.3 steering).
  def billing_source
    return "stripe" if current_paid_subscription
    return "apple" if active_apple_subscription?

    nil
  end

  def statement_files_count
    @statement_files_count ||= statement_files.count
  end

  private

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
