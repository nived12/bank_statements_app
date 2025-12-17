# frozen_string_literal: true

##
# Transactions::StatsCalculator
# Service for calculating transaction statistics from a filtered set of transactions
#
# @example
#   stats = Transactions::StatsCalculator.call(user.transactions.where(date: date_range))
#   # => { total_transactions: 50, income_total: 5000.0, expenses_total: 3000.0, ... }
#
class Transactions::StatsCalculator < ApplicationService
  def initialize(transactions)
    super()
    @transactions = transactions
  end

  def call
    calculate_stats
    success(@stats)
  end

  private

  attr_reader :transactions

  def calculate_stats
    income_total = transactions.where(transaction_type: "income").sum(:amount)
    expenses_total = transactions.where(transaction_type: ["fixed_expense", "variable_expense"]).sum(:amount)
    equity_total = income_total + expenses_total

    income_count = transactions.where(transaction_type: "income").count
    fixed_expense_count = transactions.where(transaction_type: "fixed_expense").count
    variable_expense_count = transactions.where(transaction_type: "variable_expense").count

    category_count = calculate_category_count

    total_count = transactions.respond_to?(:count) ? transactions.count : 0

    @stats = {
      total_transactions: total_count,
      income_total: income_total.to_f,
      expenses_total: expenses_total.abs.to_f,  # Convert to positive for display
      equity_total: equity_total.to_f,
      income_count: income_count,
      fixed_expense_count: fixed_expense_count,
      variable_expense_count: variable_expense_count,
      category_count: category_count
    }
  end

  def calculate_category_count
    transactions.joins(:category).distinct.count(:category_id) +
    (transactions.where(category_id: nil).count > 0 ? 1 : 0)
  rescue ActiveRecord::StatementInvalid, NoMethodError => e
    Rails.logger.error("Category count calculation failed: #{e.message}")
    0
  end
end
