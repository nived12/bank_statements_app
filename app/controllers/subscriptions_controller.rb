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
    if @active_subscription
      @billing_interval = @active_subscription.billing_interval
      # The amount actually billed, not the current list price — a subscriber on a
      # retired price is not paying today's number.
      @billing_amount_cents = @active_subscription.billing_amount_cents
      # Pay defines canceled? as ends_at? — the column is populated only once a
      # cancellation is scheduled, so it dates the end of access, not a renewal.
      @cancels_at = @active_subscription.ends_at
      @next_billing_date = @active_subscription.current_period_end if @cancels_at.blank?
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
    return_url = subscription_url
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
    session = current_user.payment_processor.billing_portal(return_url: return_url)
    redirect_to session.url, allow_other_host: true
  rescue Pay::Error
    redirect_to subscription_path, alert: t("subscription.upgrade.no_payment_method")
  end
end
