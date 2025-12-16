# frozen_string_literal: true

##
# FinancialCalculations
# Concern for user financial calculation methods
#
# Provides methods for calculating monthly summaries, category breakdowns,
# spending trends, and monthly statistics based on user transactions.
#
module FinancialCalculations
  extend ActiveSupport::Concern

  ##
  # Calculate monthly income, expenses, and net for a given month
  #
  # @param selected_month [Date] The month to calculate summary for
  # @return [Hash] Summary with income, expenses, net, counts, and has_data flag
  #
  def calculate_monthly_summary(selected_month)
    month_start = selected_month.beginning_of_month
    month_end = selected_month.end_of_month

    month_transactions = transactions.where(date: month_start..month_end)

    income = month_transactions.where(transaction_type: "income").sum(:amount)
    expenses = month_transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount)

    # Since expenses are stored as negative amounts, we need to make them positive for display
    expenses_display = expenses.abs
    net = income + expenses # expenses are already negative, so this gives us the correct net

    {
      income: income,
      expenses: expenses_display,
      net: net,
      count: month_transactions.count,
      income_count: month_transactions.where(transaction_type: "income").count,
      expense_count: month_transactions.where(transaction_type: %w[fixed_expense variable_expense]).count,
      has_data: month_transactions.any?
    }
  rescue => e
    Rails.logger.error "Error calculating monthly summary for user #{id}: #{e.message}"
    { income: 0, expenses: 0, net: 0, count: 0, has_data: false }
  end

  ##
  # Calculate category breakdown for expenses in a given month
  #
  # @param selected_month [Date] The month to calculate category summary for
  # @return [Hash] Categories array with amounts and has_data flag
  #
  def calculate_category_summary(selected_month)
    month_start = selected_month.beginning_of_month
    month_end = selected_month.end_of_month

    # Get transactions with categories for the selected month
    transactions_with_categories = transactions
                                      .joins(:category)
                                      .where(date: month_start..month_end)
                                      .where(transaction_type: [ "fixed_expense", "variable_expense" ])

    # Get transactions without categories for the selected month
    transactions_without_categories = transactions
                                        .left_joins(:category)
                                        .where(date: month_start..month_end)
                                        .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                                        .where(categories: { id: nil })

    # Group by category name and sum amounts
    result = transactions_with_categories
              .group("categories.name")
              .sum(:amount)
              .map { |category_name, amount| [ category_name, amount.abs ] } # Make amounts positive for display

    # Add uncategorized transactions
    if transactions_without_categories.any?
      uncategorized_amount = transactions_without_categories.sum(:amount).abs
      result << [ I18n.t("categories.uncategorized"), uncategorized_amount ] if uncategorized_amount > 0
    end

    # Sort by amount and take top 8
    result = result.sort_by { |_, amount| amount }.reverse.first(8)

    {
      categories: result,
      has_data: result.any?
    }
  rescue => e
    Rails.logger.error "Error calculating category summary for user #{id}: #{e.message}"
    { categories: [], has_data: false }
  end

  ##
  # Calculate spending trends for the last 6 months with data
  #
  # @param selected_month [Date] The month to use as reference (currently unused but kept for API compatibility)
  # @return [Array<Hash>] Array of months with spending amounts
  #
  def calculate_spending_trends(selected_month)
    # Get months with transaction data
    months_with_data = transactions
                        .select(Arel.sql("DATE_TRUNC('month', date)"))
                        .distinct
                        .pluck(Arel.sql("DATE_TRUNC('month', date)"))
                        .compact
                        .sort

    # Take the last 6 months with data
    recent_months = months_with_data.first(6)

    result = recent_months.map do |month_start|
      month_end = month_start.end_of_month

      expenses = transactions
                  .where(date: month_start..month_end)
                  .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                  .sum(:amount)

      {
        month: month_start.strftime("%b %Y"),
        amount: expenses.abs, # Make amount positive for display
        date: month_start
      }
    end

    result
  rescue => e
    Rails.logger.error "Error calculating spending trends for user #{id}: #{e.message}"
    []
  end

  ##
  # Calculate detailed monthly statistics
  #
  # @param selected_month [Date] The month to calculate stats for
  # @return [Hash] Detailed stats including averages, maximums, and top categories
  #
  def calculate_monthly_stats(selected_month)
    month_start = selected_month.beginning_of_month
    month_end = selected_month.end_of_month

    month_transactions = transactions.where(date: month_start..month_end)

    {
      total_transactions: month_transactions.count,
      income_transactions: month_transactions.where(transaction_type: "income").count,
      expense_transactions: month_transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).count,
      average_income: month_transactions.where(transaction_type: "income").average(:amount) || 0,
      average_expense: month_transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).average(:amount)&.abs || 0,
      largest_income: month_transactions.where(transaction_type: "income").maximum(:amount) || 0,
      largest_expense: month_transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).minimum(:amount)&.abs || 0,
      top_categories: calculate_top_categories_for_month(month_transactions),
      has_data: month_transactions.any?
    }
  rescue => e
    Rails.logger.error "Error calculating monthly stats for user #{id}: #{e.message}"
    default_monthly_stats
  end

  private

  ##
  # Calculate top 3 categories by spending for given transactions
  #
  # @param transactions [ActiveRecord::Relation] Transaction scope to analyze
  # @return [Array<Hash>] Top 3 categories with names and amounts
  #
  def calculate_top_categories_for_month(transactions)
    # Get transactions with categories
    transactions_with_categories = transactions.joins(:category)
                                              .where(transaction_type: [ "fixed_expense", "variable_expense" ])

    # Get transactions without categories
    transactions_without_categories = transactions.left_joins(:category)
                                                 .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                                                 .where(categories: { id: nil })

    # Group by category and sum amounts
    result = transactions_with_categories
              .group("categories.name")
              .sum(:amount)
              .map { |name, amount| { name: name, amount: amount.abs } }

    # Add uncategorized if any
    if transactions_without_categories.any?
      uncategorized_amount = transactions_without_categories.sum(:amount).abs
      result << { name: I18n.t("categories.uncategorized"), amount: uncategorized_amount } if uncategorized_amount > 0
    end

    # Sort and take top 3
    result.sort_by { |cat| cat[:amount] }.reverse.first(3)
  rescue => e
    Rails.logger.error "Error calculating top categories for user #{id}: #{e.message}"
    []
  end

  ##
  # Default monthly stats structure with zero values
  #
  # @return [Hash] Empty stats structure
  #
  def default_monthly_stats
    {
      total_transactions: 0,
      income_transactions: 0,
      expense_transactions: 0,
      average_income: 0,
      average_expense: 0,
      largest_income: 0,
      largest_expense: 0,
      top_categories: [],
      has_data: false
    }
  end
end
