# frozen_string_literal: true

##
# DebtPaymentSchedule
# Handles payment due date calculations and schedule tracking
#
module DebtPaymentSchedule
  extend ActiveSupport::Concern

  # Calculate the next payment due date based on due_day_of_month
  # Returns nil if due_day_of_month is not set
  def calculate_next_due_date
    return if due_day_of_month.blank?

    today = Date.current
    year = today.year
    month = today.month

    # Try to create date with due_day_of_month
    # Handle month-end edge cases (e.g., due on 31st in February)
    candidate_date = begin
      Date.new(year, month, due_day_of_month)
    rescue ArgumentError
      # If day doesn't exist in current month (e.g., Feb 31), use last day of month
      Date.new(year, month, -1)
    end

    # If candidate date is in the past, move to next month
    if candidate_date < today
      next_month = today.next_month
      candidate_date = begin
        Date.new(next_month.year, next_month.month, due_day_of_month)
      rescue ArgumentError
        Date.new(next_month.year, next_month.month, -1)
      end
    end

    candidate_date
  end

  # Calculate days until next payment is due
  # Returns nil if no due date is set
  # Returns negative number if overdue
  def payment_due_in_days
    return if due_day_of_month.blank?

    next_due = calculate_next_due_date
    return if next_due.blank?

    (next_due - Date.current).to_i
  end

  # Check if payment is overdue
  def payment_overdue?
    return false if payment_due_in_days.blank?

    payment_due_in_days.negative?
  end
end
