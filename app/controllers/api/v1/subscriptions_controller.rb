# frozen_string_literal: true

module Api
  module V1
    class SubscriptionsController < BaseController
      include SubscriptionManagement

      # GET /api/v1/subscription
      def status
        sub = active_premium_subscription
        if sub
          @plan = "premium"
          @status = sub.status.to_s
          @billing_interval = billing_interval_for(sub)
          @trial_ends_at = sub.trial_ends_at
          @current_period_end = sub.ends_at
          @cancel_at_period_end = sub.on_grace_period?
        elsif current_user.trial_ends_at.present? && current_user.trial_ends_at > Time.current
          @plan = nil
          @status = "trialing"
          @billing_interval = nil
          @trial_ends_at = current_user.trial_ends_at
          @current_period_end = nil
          @cancel_at_period_end = false
        else
          @plan = nil
          @status = nil
          @billing_interval = nil
          @trial_ends_at = nil
          @current_period_end = nil
          @cancel_at_period_end = false
        end
        @ai_calls_used = current_user.ai_usage_count
        @ai_calls_limit = SubscriptionAccess.free_tier_ai_calls
        @statement_files_used = current_user.statement_files.count
        @statement_files_limit = SubscriptionAccess.free_tier_statement_files
      end

      # POST /api/v1/subscription/checkout
      def checkout
        unless %w[month year].include?(params[:interval])
          render_error(
            "INVALID_INTERVAL",
            message: I18n.t("api.subscription.invalid_interval"),
            status: :unprocessable_content
          )
          return
        end

        price_id = if params[:interval] == "year"
          User.stripe_premium_annual_price_id
        else
          User.stripe_premium_monthly_price_id
        end

        if price_id.blank?
          render_error(
            "SERVICE_UNAVAILABLE",
            message: I18n.t("api.subscription.price_not_configured"),
            status: :service_unavailable
          )
          return
        end

        current_user.set_payment_processor(:stripe) unless current_user.payment_processor
        session = current_user.payment_processor.checkout(
          mode: "subscription",
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: subscription_url(success: 1),
          cancel_url: subscription_url
        )

        @checkout_url = session.url
      end

      # GET /api/v1/subscription/portal
      def portal
        return_url = ENV.fetch("APP_URL", "https://app.vitt.io")

        current_user.set_payment_processor(:stripe) unless current_user.payment_processor
        session = current_user.payment_processor.billing_portal(return_url: return_url)
        @portal_url = session.url
      rescue Pay::Error
        render_error(
          "NO_PAYMENT_METHOD",
          message: I18n.t("api.subscription.no_payment_method"),
          status: :unprocessable_content
        )
      end

      private

      def billing_interval_for(sub)
        return "year" if sub.processor_plan == User.stripe_premium_annual_price_id

        "month"
      end
    end
  end
end
