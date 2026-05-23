# frozen_string_literal: true

class PricingController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!

  def index
    @subscription_state    = compute_subscription_state
    @trial_days_remaining  = compute_trial_days_remaining
    @trial_banner_key      = compute_trial_banner_key
    @trial_quota_exhausted = @trial_banner_key != "pricing.trial_banner.days_only"
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

  # Picks the right banner key based on which quotas (if any) the trial user
  # has exhausted. Premium / guest / expired states bypass this — banner is
  # only re-keyed for `:on_trial`.
  def compute_trial_banner_key
    return "pricing.trial_banner.days_only" unless @subscription_state == :on_trial

    statement_exhausted = !current_user.subscription_access_result[:allowed]
    ai_exhausted        = !current_user.ai_access_result[:allowed]

    if statement_exhausted && ai_exhausted
      "pricing.trial_banner.both_quotas_and_days"
    elsif ai_exhausted
      "pricing.trial_banner.ai_quota_and_days"
    elsif statement_exhausted
      "pricing.trial_banner.statement_quota_and_days"
    else
      "pricing.trial_banner.days_only"
    end
  end
end
