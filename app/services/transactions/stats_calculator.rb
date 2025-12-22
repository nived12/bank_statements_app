# frozen_string_literal: true

##
# Transactions::StatsCalculator
# Service for calculating transaction statistics for the current user
#
# @example
#   stats = Transactions::StatsCalculator.call({ bank_account_id: 1, from_date: '2024-01-01' })
#   # => { total_transactions: 50, income_total: 5000.0, expenses_total: 3000.0, ... }
#
class Transactions::StatsCalculator < ApplicationService
  def initialize(params = {})
    super()
    @params = params
  end

  def call
    calculate_stats
    success(@stats)
  end

  private

  attr_reader :params

  def transactions_scope
    Current.user.transactions
      .includes(:bank_account, :category)
      .filter_by(filtering_params)
      .search_by(searching_params)
  end

  def filtering_params
    params.slice(:bank_account_id, :statement_file_id, :transaction_type, :from_date, :to_date).compact
  end

  def searching_params
    { description: params[:search] }.compact
  end

  def calculate_stats
    aggregated = transactions_scope.reorder(nil).pluck(:transaction_type, :amount)

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
    scope = transactions_scope
    return 0 if scope.blank?

    category_ids = scope.pluck(:category_id)
    category_ids.compact.uniq.size + (category_ids.include?(nil) ? 1 : 0)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error("Category count calculation failed: #{e.message}")
    0
  end
end
