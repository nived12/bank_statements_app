# frozen_string_literal: true

module Subscriptions
  # Applies one RevenueCat event to a user's App Store entitlement.
  #
  # Apple owns the subscription; this only mirrors "is it live, and what are they
  # paying?" so SubscriptionAccess can answer without calling out. Every write is an
  # upsert of the single row, which is what makes RevenueCat's retries safe.
  class AppleEntitlementSyncer < ApplicationService
    # Product ids as configured in App Store Connect. Unknown ids still grant access —
    # a paying customer must never be locked out over a display detail — but report no
    # interval rather than guessing one.
    PRODUCT_INTERVALS = {
      "io.vitt.app.premium.monthly" => "month",
      "io.vitt.app.premium.annual" => "year"
    }.freeze

    # Events that carry a current expiry. CANCELLATION means auto-renew was switched
    # off, not that access ended, so it is applied like any other state update and
    # only flips auto_renews.
    HANDLED_TYPES = %w[
      INITIAL_PURCHASE RENEWAL PRODUCT_CHANGE CANCELLATION UNCANCELLATION
      EXPIRATION BILLING_ISSUE SUBSCRIPTION_EXTENDED
    ].freeze

    def initialize(event:)
      super()
      @event = event.with_indifferent_access
    end

    def call
      return report_transfer if @event[:type] == "TRANSFER"
      return success(ignored: :event_type) unless HANDLED_TYPES.include?(@event[:type])
      # Only App Store purchases belong in this table. Play Store events would arrive
      # here too if Android IAP is ever added through the same RevenueCat project.
      return success(ignored: :store) unless @event[:store] == "APP_STORE"
      return success(ignored: :no_expiry) if expires_at.blank?

      user = User.find_by(id: @event[:app_user_id])
      # A deleted account is permanent — acknowledged, not retried.
      return success(ignored: :unknown_user) if user.nil?

      apply(user)
      success(user_id: user.id)
    end

    private

    # Apple moved this subscription to a different Vittio account — the same person
    # signing up again after deleting their account, or restoring onto a second one.
    # The payload carries only the two id lists: no product, no expiry, no price, so
    # the new owner cannot be granted access from it without asking RevenueCat what
    # they now own. That API client is not worth its maintenance at this frequency.
    #
    # So this is deliberately hand-operated: alert, and move the entitlement manually.
    # The previous account keeps its access on purpose — it is normally the same human,
    # and revoking would take away what they paid for while granting nothing back.
    def report_transfer
      from = Array(@event[:transferred_from]).join(",")
      to   = Array(@event[:transferred_to]).join(",")
      message = "[RevenueCat] entitlement transferred from user(s) #{from} to #{to} — move it by hand"

      Rails.logger.warn(message)
      Sentry.capture_message(message, level: :warning) if defined?(Sentry)

      success(transferred_from: from, transferred_to: to)
    end

    def apply(user)
      entitlement = user.apple_premium_subscription || user.build_apple_premium_subscription
      entitlement.update!(
        expires_at: expires_at,
        billing_interval: PRODUCT_INTERVALS[@event[:product_id]],
        billing_amount_cents: amount_cents,
        billing_currency: @event[:currency]&.upcase,
        original_transaction_id: @event[:original_transaction_id],
        auto_renews: @event[:type] != "CANCELLATION"
      )
    end

    def expires_at
      ms = @event[:expiration_at_ms]
      return if ms.blank?

      Time.zone.at(ms.to_i / 1000.0)
    end

    # What Apple actually charged, in the currency they charged it in — never a
    # configured list price. A subscriber on a retired price is not paying today's
    # number, and Apple's prices rotate the same way Stripe's do.
    def amount_cents
      price = @event[:price_in_purchased_currency]
      return if price.blank?

      (price.to_d * 100).round
    end
  end
end
