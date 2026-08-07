# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  include SubscriptionManagement

  # GET /subscription
  def show
    if params[:success] == "1"
      sync_subscription_from_stripe_session(params[:stripe_checkout_session_id])
      ::Analytics.capture(distinct_id: current_user.id, event: "subscription_started")
      redirect_to dashboard_path, notice: t("subscription.upgrade.success_notice")
      return
    end
    @subscription_result = current_user.subscription_access_result
    @trial_ends_at = current_user.trial_ends_at
    @active_subscription = active_premium_subscription
    # Terms come from the user so an App Store subscriber, who has no Pay row at all,
    # still sees what they pay. The amount is what was actually billed, not the current
    # list price — a subscriber on a retired price is not paying today's number.
    @billing_source = current_user.billing_source
    @billing_interval = current_user.billing_interval
    @billing_amount_cents = current_user.billing_amount_cents
    @billing_currency = current_user.billing_currency
    if @active_subscription
      # Pay defines canceled? as ends_at? — the column is populated only once a
      # cancellation is scheduled, so it dates the end of access, not a renewal.
      @cancels_at = @active_subscription.ends_at
      @next_billing_date = @active_subscription.current_period_end if @cancels_at.blank?
    elsif @billing_source == "apple"
      @next_billing_date = current_user.apple_premium_subscription.expires_at
    end
  end

  # POST /subscription/checkout
  def checkout
    if current_user.active_paid_subscription?
      redirect_to subscription_path, notice: t("subscription.upgrade.already_subscribed")
      return
    end

    interval = params[:interval]
    unless %w[month year].include?(interval)
      redirect_to subscription_path, alert: t("subscription.upgrade.invalid_interval")
      return
    end

    price_id = if interval == "year"
      User.stripe_premium_annual_price_id
    else
      User.stripe_premium_monthly_price_id
    end

    if price_id.blank?
      redirect_to subscription_path, alert: t("subscription.upgrade.price_not_configured")
      return
    end

    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
    session = current_user.payment_processor.checkout(
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: with_checkout_session_id(subscription_url(success: 1)),
      cancel_url: subscription_url
    )

    redirect_to session.url, allow_other_host: true
  end

  # GET /subscription/portal
  def portal
    # Apple bills this user; Stripe has nothing to show and creating a customer
    # here is the first step toward a double charge. checkout is already covered
    # by its active_paid_subscription? guard, which counts App Store entitlements.
    if current_user.active_apple_subscription?
      redirect_to subscription_path, notice: t("api.subscription.managed_by_apple")
      return
    end

    return_url = subscription_url
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
    session = current_user.payment_processor.billing_portal(return_url: return_url)
    redirect_to session.url, allow_other_host: true
  rescue Pay::Error
    redirect_to subscription_path, alert: t("subscription.upgrade.no_payment_method")
  end
end
