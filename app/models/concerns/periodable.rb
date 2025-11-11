# frozen_string_literal: true

# Periodable concern provides shared functionality for calculating progress over time periods
# Used by both Debt and Saving models to track achievements and contributions over date ranges
module Periodable
  extend ActiveSupport::Concern

  # Calculate progress (achieved amount) for a specific date range
  # Returns a hash with achieved amount, target amount, and percentage
  #
  # @param start_date [Date] Beginning of period
  # @param end_date [Date] End of period
  # @return [Hash] {:achieved, :target, :percentage}
  def progress_for_period(start_date, end_date)
    achieved = calculate_achieved_for_period(start_date, end_date)
    target = calculate_target_for_period(start_date, end_date)
    percentage = target.positive? ? ((achieved.to_f / target) * 100).round(2) : 0.0

    {
      achieved: achieved,
      target: target,
      percentage: percentage,
      start_date: start_date,
      end_date: end_date
    }
  end

  # Calculate progress for the current month
  # @return [Hash] Progress data for current month
  def current_month_progress
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month
    progress_for_period(start_date, end_date)
  end

  # Generate a monthly timeline of progress for the last N months
  # @param num_months [Integer] Number of months to include (default: 12)
  # @return [Array<Hash>] Array of monthly progress data
  def monthly_timeline(num_months = 12)
    timeline = []
    current_date = Date.current

    num_months.times do |i|
      month_start = (current_date - i.months).beginning_of_month
      month_end = month_start.end_of_month

      # Don't include future months
      next if month_start > Date.current

      timeline << progress_for_period(month_start, month_end).merge(
        month: month_start.strftime("%B %Y"),
        month_short: month_start.strftime("%b %Y")
      )
    end

    timeline.reverse
  end

  private

  # Calculate achieved amount for a period based on linked transactions
  # Must be implemented by including model
  def calculate_achieved_for_period(start_date, end_date)
    return 0 unless respond_to?(:transactions)

    transactions_in_period = transactions.where(date: start_date..end_date)

    if is_a?(Debt)
      # For debts, sum debt_transactions amount_applied
      debt_transactions.joins(:transaction_record)
                      .where(transactions: { date: start_date..end_date })
                      .sum(:amount_applied)
    elsif is_a?(Saving)
      # For savings, sum saving_transactions amount_applied
      saving_transactions.joins(:transaction_record)
                        .where(transactions: { date: start_date..end_date })
                        .sum(:amount_applied)
    else
      0
    end
  end

  # Calculate target amount for a period
  # Must be implemented by including model or overridden
  def calculate_target_for_period(start_date, end_date)
    # Calculate number of months in period
    months_in_period = ((end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)) + 1

    if is_a?(Debt) && respond_to?(:target_payment_amount) && target_payment_amount.present?
      # For debts, use target_payment_amount
      target_payment_amount * months_in_period
    elsif is_a?(Saving) && respond_to?(:target_contribution_amount)
      # For savings, use target_contribution_amount based on mode
      return 0 if contribution_mode.nil? # No target when contribution_mode is nil

      case contribution_mode
      when "fixed"
        target_contribution_amount.to_f * months_in_period
      when "calculated"
        # Calculate from goal deadline
        calculated_monthly_contribution * months_in_period
      else
        0
      end
    else
      0
    end
  end
end
