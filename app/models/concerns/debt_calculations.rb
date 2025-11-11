# frozen_string_literal: true

##
# DebtCalculations
# Handles payment calculations including amortization formulas and interest rate conversions
#
module DebtCalculations
  extend ActiveSupport::Concern

  # Calculate or return the monthly payment amount with interest
  def calculated_monthly_payment
    return target_payment_amount if payment_mode == "fixed"
    return 0 if payment_mode != "calculated"

    calculate_required_payment_with_interest
  end

  # Calculate suggested payoff date based on fixed payment amount (with interest)
  # Returns nil if payment_mode is not "fixed" or target_payment_amount is blank
  def suggested_payoff_date
    return if payment_mode != "fixed"
    return if target_payment_amount.blank? || target_payment_amount <= 0
    return if current_balance.blank? || current_balance <= 0
    return Date.current if current_balance <= 0 # Already paid off

    # Get annual interest rate (default to 0 if not set)
    annual_rate = (interest_rate || 0) / 100.0
    return if annual_rate.negative?

    # Convert annual rate to period rate
    period_rate = calculate_period_rate(annual_rate)

    # Check if payment is enough to cover interest
    interest_per_period = current_balance * period_rate
    return if target_payment_amount <= interest_per_period # Payment doesn't cover interest

    # Calculate number of periods needed using amortization formula
    # n = -log(1 - (r * PV) / P) / log(1 + r)
    if period_rate.zero?
      # No interest - simple division
      periods_needed = (current_balance / target_payment_amount).ceil
    else
      numerator = 1 - ((period_rate * current_balance) / target_payment_amount)
      return if numerator <= 0 # Payment doesn't pay down principal

      periods_needed = (-Math.log(numerator) / Math.log(1 + period_rate)).ceil
    end

    # Calculate the date
    calculate_future_date_from_periods(periods_needed)
  end

  private

  # Calculate required payment with interest for calculated mode
  def calculate_required_payment_with_interest
    return 0 if target_payoff_date.blank?
    return 0 if current_balance.blank? || current_balance <= 0
    return 0 if target_payoff_date < Date.current

    # Get annual interest rate (default to 0 if not set)
    annual_rate = (interest_rate || 0) / 100.0

    # Convert annual rate to period rate
    period_rate = calculate_period_rate(annual_rate)

    # Calculate number of periods until target date
    periods_remaining = calculate_periods_until_date(target_payoff_date)
    return current_balance if periods_remaining <= 0

    # Use amortization formula: P = (r * PV) / (1 - (1 + r)^-n)
    if period_rate.zero?
      # No interest - simple division
      (current_balance / periods_remaining).round(2)
    else
      numerator = period_rate * current_balance
      denominator = 1 - ((1 + period_rate) ** -periods_remaining)
      (numerator / denominator).round(2)
    end
  end

  # Convert annual interest rate to period rate based on payment_frequency
  def calculate_period_rate(annual_rate)
    return 0 if annual_rate.zero?

    case payment_frequency
    when "weekly"
      annual_rate / 52.0
    when "biweekly"
      annual_rate / 26.0
    when "semimonthly"
      annual_rate / 24.0
    when "monthly", nil
      annual_rate / 12.0
    else
      annual_rate / 12.0 # Default to monthly
    end
  end

  # Calculate number of periods from today until target date
  def calculate_periods_until_date(target_date)
    today = Date.current
    days_remaining = (target_date - today).to_i
    return 0 if days_remaining <= 0

    case payment_frequency
    when "weekly"
      (days_remaining / 7.0).ceil
    when "biweekly"
      (days_remaining / 14.0).ceil
    when "semimonthly"
      (days_remaining / 15.0).ceil
    when "monthly", nil
      # Calculate months
      months = (target_date.year - today.year) * 12 + (target_date.month - today.month)
      [months, 1].max
    else
      # Default to monthly
      months = (target_date.year - today.year) * 12 + (target_date.month - today.month)
      [months, 1].max
    end
  end

  # Calculate future date based on number of periods
  def calculate_future_date_from_periods(periods)
    today = Date.current

    case payment_frequency
    when "weekly"
      today + (periods * 7).days
    when "biweekly"
      today + (periods * 14).days
    when "semimonthly"
      today + (periods * 15).days
    when "monthly", nil
      today + periods.months
    else
      today + periods.months # Default to monthly
    end
  end
end
