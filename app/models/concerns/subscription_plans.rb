# frozen_string_literal: true

module SubscriptionPlans
  extend ActiveSupport::Concern

  PAID_PLAN_NAMES = %w[pro enterprise].freeze
  UPLOAD_GRACE_PERIOD_DAYS = 3

  class_methods do
    def paid_plan_names
      config = Rails.application.config_for(:subscription_plans) rescue {}
      (config["paid_plan_names"] || PAID_PLAN_NAMES).map(&:to_s)
    end

    def stripe_pro_price_id
      ENV.fetch("STRIPE_PRO_PRICE_ID", nil)
    end

    def stripe_enterprise_price_id
      ENV.fetch("STRIPE_ENTERPRISE_PRICE_ID", nil)
    end
  end
end
