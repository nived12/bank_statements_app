# frozen_string_literal: true

class PricingController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  def index
    @subscription_state = compute_subscription_state
    @trial_days_remaining = compute_trial_days_remaining
  end

  private

  def compute_subscription_state
    return :guest unless current_user

    result = current_user.subscription_access_result
    if result[:allowed]
      if current_user.trial_ends_at.present? && current_user.trial_ends_at > Time.current
        :on_trial
      else
        :premium
      end
    else
      :expired
    end
  end

  def compute_trial_days_remaining
    return 0 unless current_user&.trial_ends_at.present?
    return 0 unless current_user.trial_ends_at > Time.current

    ((current_user.trial_ends_at - Time.current) / 1.day).ceil
  end
end
