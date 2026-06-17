# frozen_string_literal: true

class PricingController < ApplicationController
  include MarketingLayout

  def index
    @subscription_state   = compute_subscription_state
    @trial_days_remaining = compute_trial_days_remaining
  end

  private

  def compute_subscription_state
    return :guest unless current_user
    return :premium if current_user.active_paid_subscription?
    return :on_trial if current_user.active_trial?

    :expired
  end

  def compute_trial_days_remaining
    return 0 unless current_user&.trial_ends_at.present?
    return 0 unless current_user.trial_ends_at > Time.current

    ((current_user.trial_ends_at - Time.current) / 1.day).ceil
  end
end
