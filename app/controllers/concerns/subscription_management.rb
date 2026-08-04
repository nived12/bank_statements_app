# frozen_string_literal: true

module SubscriptionManagement
  extend ActiveSupport::Concern

  private

  def active_premium_subscription
    current_user.pay_subscriptions.find do |sub|
      User.paid_plan_names.include?(sub.name.to_s) &&
        sub.status.to_s == "active"
    end
  end

  # Stripe swaps the literal {CHECKOUT_SESSION_ID} token into the URL it returns
  # the buyer to. Passing it through a url helper would percent-encode the braces
  # and Stripe would leave it unsubstituted, so it is appended to the built URL.
  def with_checkout_session_id(url)
    separator = url.include?("?") ? "&" : "?"
    "#{url}#{separator}stripe_checkout_session_id={CHECKOUT_SESSION_ID}"
  end

  # Syncs on the return trip so a missed webhook cannot leave a paying user
  # without access. The webhook stays the backstop for everything that happens
  # after checkout — renewals, cancellations, payment failures.
  def sync_subscription_from_stripe_session(session_id)
    return if session_id.blank?

    stripe_session = Stripe::Checkout::Session.retrieve(session_id)
    Pay::Stripe::Subscription.sync(stripe_session.subscription) if stripe_session.subscription.present?
    # Broad on purpose: the buyer has already been charged by the time they land
    # here, so nothing this sync can do is worth turning the confirmation page
    # into a 500. Pay wraps Stripe errors in its own classes, and sync writes to
    # the DB, so Stripe::StripeError alone would not cover it. The webhook
    # remains the backstop; Sentry keeps the failure from being silent.
  rescue Stripe::StripeError, Pay::Error, ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("[Subscriptions] Stripe sync failed for session #{session_id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
