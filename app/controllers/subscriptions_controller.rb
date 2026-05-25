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
      @billing_interval = @active_subscription.processor_plan == User.stripe_premium_annual_price_id ? :year : :month
      @next_billing_date = @active_subscription.ends_at
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
      success_url: subscription_url(success: 1),
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

  private

  def sync_subscription_from_stripe_session(session_id)
    return if session_id.blank?

    stripe_session = Stripe::Checkout::Session.retrieve(session_id)
    Pay::Stripe::Subscription.sync(stripe_session.subscription) if stripe_session.subscription.present?
  rescue Stripe::StripeError => e
    Rails.logger.warn("[Subscriptions] Stripe sync failed for session #{session_id}: #{e.message}")
  end
end
