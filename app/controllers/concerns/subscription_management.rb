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
end
