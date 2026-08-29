# frozen_string_literal: true

# Periodable concern provides shared functionality for calculating progress over time periods
# Used by both Debt and Saving models to track achievements and contributions over date ranges
module Periodable
  extend ActiveSupport::Concern

  included do
    validates :opening_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :opening_balance_date, presence: true
    validate :opening_balance_date_cannot_be_in_future

    # Link/unlink events recalculate on their own (SavingTransaction/DebtTransaction
    # callbacks), but editing the anchor itself has no link event to ride along with —
    # without this, retyping opening_balance updates the anchor and leaves the displayed
    # current_amount/current_balance stale until the next unrelated link fires.
    after_save :recalculate_balance!, if: -> {
      saved_change_to_opening_balance? || saved_change_to_opening_balance_date?
    }
  end

  # Transactions this record's balance actually counts: linked, and dated after
  # opening_balance_date. Shared by recalculate_current_amount!/recalculate_current_balance!,
  # balance_as_of, and the period/timeline math below, so all four agree on what "counts".
  def counted_link_transactions
    if is_a?(Debt)
      debt_transactions.joins(:transaction_record).merge(Transaction.relevant_for_balance(opening_balance_date))
    elsif is_a?(Saving)
      saving_transactions.joins(:transaction_record).merge(Transaction.relevant_for_balance(opening_balance_date))
    end
  end

  # The date the current balance is actually true as of: the anchor date, or the most
  # recent counted transaction if one landed after it.
  def balance_as_of
    latest = counted_link_transactions&.maximum("transactions.date")
    [opening_balance_date, latest].compact.max
  end

  def recalculate_balance!
    if is_a?(Debt)
      recalculate_current_balance!
    elsif is_a?(Saving)
      recalculate_current_amount!
    end
  end

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

  # Savings track contribution_frequency, debts payment_frequency — the maths below is
  # the same for both, so resolve it once here.
  def tracking_frequency
    respond_to?(:payment_frequency) ? payment_frequency : contribution_frequency
  end

  # How many contribution/payment periods fall between two dates. The user enters an
  # amount "per period", so anything that spreads a total over time has to divide by
  # periods, not months — otherwise a weekly plan is quoted at a monthly figure.
  def periods_between(start_date, end_date)
    days = (end_date - start_date).to_i
    return 0 if days <= 0

    case tracking_frequency
    when "weekly" then (days / 7.0).ceil
    when "biweekly" then (days / 14.0).ceil
    when "semimonthly" then (days / 15.0).ceil
    else ((end_date.year - start_date.year) * 12) + (end_date.month - start_date.month)
    end
  end

  def periods_until(date)
    periods_between(Date.current, date)
  end


  # Calculate achieved amount for a period based on linked transactions
  # Must be implemented by including model
  def calculate_achieved_for_period(start_date, end_date)
    counted_link_transactions&.where(transactions: { date: start_date..end_date })&.sum(:amount_applied) || 0
  end

  # Calculate target amount for a period
  # Must be implemented by including model or overridden
  def calculate_target_for_period(start_date, end_date)
    # Calculate number of months in period
    periods = [periods_between(start_date, end_date), 1].max

    if is_a?(Debt) && respond_to?(:target_payment_amount) && target_payment_amount.present?
      # For debts, use target_payment_amount
      target_payment_amount * periods
    elsif is_a?(Saving) && respond_to?(:target_contribution_amount)
      # For savings, use target_contribution_amount based on mode
      return 0 if contribution_mode.nil? # No target when contribution_mode is nil

      case contribution_mode
      when "fixed"
        target_contribution_amount.to_f * periods
      when "calculated"
        # Calculate from goal deadline
        calculated_period_contribution * periods
      else
        0
      end
    else
      0
    end
  end

  def opening_balance_date_cannot_be_in_future
    return if opening_balance_date.blank? || opening_balance_date <= Date.current

    key = is_a?(Debt) ? "debts" : "savings"
    errors.add(:opening_balance_date, I18n.t("#{key}.errors.opening_balance_date_future"))
  end
end
