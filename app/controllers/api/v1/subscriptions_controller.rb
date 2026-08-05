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
          @current_period_end = sub.current_period_end
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
        @ai_calls_used = current_user.quota.ai_usage_count
        is_premium = current_user.active_paid_subscription?
        @ai_calls_limit = if is_premium
          SubscriptionAccess.premium_monthly_ai_calls
        else
          SubscriptionAccess.free_tier_ai_calls
        end
        @statement_files_used = current_user.statement_files_count
        @statement_files_limit = is_premium ? nil : SubscriptionAccess.free_tier_statement_files
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

        if current_user.active_paid_subscription?
          active_sub = current_user.current_paid_subscription
          if active_sub.processor_plan == price_id
            render_error(
              "ALREADY_SUBSCRIBED",
              message: I18n.t("api.subscription.already_subscribed"),
              status: :unprocessable_content
            )
            return
          end
          # always_invoice, not create_prorations: the latter defers the charge to
          # the upcoming invoice, a year out on an annual plan.
          begin
            active_sub.swap(price_id, proration_behavior: "always_invoice")
          rescue Pay::Error, Pay::PaymentError => e
            # Charging synchronously means declines and SCA land here. Pay wraps
            # Stripe errors, and Pay::PaymentError is not a Pay::Error.
            Rails.logger.warn("[Subscriptions] swap failed for user #{current_user.id}: #{e.message}")
            render_error(
              "PAYMENT_FAILED",
              message: I18n.t("api.subscription.payment_failed"),
              status: :payment_required
            )
            return
          end

          render json: { data: { switched: true }, message: I18n.t("api.subscription.plan_switched") }
          return
        end

        current_user.set_payment_processor(:stripe) unless current_user.payment_processor
        session = current_user.payment_processor.checkout(
          mode: "subscription",
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: with_checkout_session_id(checkout_success_url),
          cancel_url: pricing_url
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

      # nil for manually granted subscriptions — they have no Stripe price, so no
      # interval. The API already emitted null here for users with no subscription.
      def billing_interval_for(sub)
        sub.billing_interval&.to_s
      end
    end
  end
end
