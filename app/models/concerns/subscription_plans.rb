# frozen_string_literal: true

module SubscriptionPlans
  extend ActiveSupport::Concern

  PAID_PLAN_NAMES = %w[premium].freeze

  class_methods do
    def paid_plan_names
      config = Rails.application.config_for(:subscription_plans) rescue {}
      (config["paid_plan_names"] || PAID_PLAN_NAMES).map(&:to_s)
    end

    def stripe_premium_monthly_price_id
      ENV.fetch("STRIPE_PREMIUM_MONTHLY_PRICE_ID", nil)
    end

    def stripe_premium_annual_price_id
      ENV.fetch("STRIPE_PREMIUM_ANNUAL_PRICE_ID", nil)
    end
  end
end
