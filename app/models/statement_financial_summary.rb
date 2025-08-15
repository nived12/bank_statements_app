class StatementFinancialSummary < ApplicationRecord
  belongs_to :statement_file

  # Enums
  enum statement_type: {
    savings: "savings",
    credit: "credit",
    payroll: "payroll"
  }, _prefix: true

  # Validations
  validates :statement_type, presence: true
  validates :statement_type_data, presence: true
  validates :initial_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :final_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :statement_period_start, presence: true
  validates :statement_period_end, presence: true
  validates :days_in_period, presence: true, numericality: { greater_than: 0 }

  # Ensure end date is after start date
  validate :period_end_after_start

  # Scopes
  scope :by_period, ->(start_date, end_date) {
    where(statement_period_start: start_date..end_date)
  }

  # Type-specific getters
  def savings_data
    return nil unless savings?
    statement_type_data
  end

  def credit_data
    return nil unless credit?
    statement_type_data
  end

  def payroll_data
    return nil unless payroll?
    statement_type_data
  end

  # Helper methods for common calculations
  def net_movement
    final_balance - initial_balance
  end

  def period_duration
    (statement_period_end - statement_period_start).to_i + 1
  end

  def average_daily_balance
    return nil unless statement_type_data["average_balance"]
    statement_type_data["average_balance"]
  end

  # Type-specific helper methods
  def total_deposits
    if savings? || payroll?
      statement_type_data["total_deposits"] || 0
    elsif credit?
      statement_type_data["total_payments"] || 0
    else
      0
    end
  end

  def total_withdrawals
    if savings? || payroll?
      statement_type_data["total_withdrawals"] || 0
    elsif credit?
      statement_type_data["total_charges"] || 0
    else
      0
    end
  end

  def interest_earned
    if savings? || payroll?
      statement_type_data["interest_earned"] || 0
    elsif credit?
      -(statement_type_data["interest_charged"] || 0)
    else
      0
    end
  end

  def credit_limit
    return nil unless credit?
    statement_type_data["credit_limit"]
  end

  def available_credit
    return nil unless credit?
    statement_type_data["available_credit"]
  end

  def payment_to_avoid_interest
    return nil unless credit?
    statement_type_data["payment_to_avoid_interest"]
  end

  def minimum_payment
    return nil unless credit?
    statement_type_data["minimum_payment"]
  end

  private

  def period_end_after_start
    return unless statement_period_start && statement_period_end

    if statement_period_end <= statement_period_start
      errors.add(:statement_period_end, "must be after start date")
    end
  end
end
