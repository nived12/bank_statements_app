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
    aggregated = transactions.reorder(nil).pluck(:transaction_type, :amount)

    income_total = expenses_total = 0.0
    income_count = fixed_expense_count = variable_expense_count = 0

    aggregated.each do |type, amount|
      case type
      when "income"
        income_total += amount.to_f
        income_count += 1
      when "fixed_expense"
        expenses_total += amount.to_f
        fixed_expense_count += 1
      when "variable_expense"
        expenses_total += amount.to_f
        variable_expense_count += 1
      end
    end

    @stats = {
      total_transactions: aggregated.size,
      income_total: income_total,
      expenses_total: expenses_total,
      equity_total: income_total + expenses_total,
      income_count: income_count,
      fixed_expense_count: fixed_expense_count,
      variable_expense_count: variable_expense_count,
      category_count: calculate_category_count
    }
  end

  def calculate_category_count
    return 0 if transactions.blank?

    category_ids = transactions.pluck(:category_id)
    category_ids.compact.uniq.size + (category_ids.include?(nil) ? 1 : 0)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Category count calculation failed: #{e.message}")
    0
  end
end
