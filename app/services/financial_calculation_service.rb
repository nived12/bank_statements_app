# app/services/financial_calculation_service.rb
class FinancialCalculationService
  class << self
    def calculate_monthly_summary(selected_month)
      month_start = selected_month.beginning_of_month
      month_end = selected_month.end_of_month

      transactions = Current.user.transactions.where(date: month_start..month_end)

      income = transactions.where(transaction_type: "income").sum(:amount)
      expenses = transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount)

      # Since expenses are stored as negative amounts, we need to make them positive for display
      expenses_display = expenses.abs
      net = income + expenses # expenses are already negative, so this gives us the correct net

      {
        income: income,
        expenses: expenses_display,
        net: net,
        count: transactions.count,
        income_count: transactions.where(transaction_type: "income").count,
        expense_count: transactions.where(transaction_type: %w[fixed_expense variable_expense]).count,
        has_data: transactions.any?
      }
    rescue => e
      Rails.logger.error "Error calculating monthly summary: #{e.message}"
      { income: 0, expenses: 0, net: 0, count: 0, has_data: false }
    end

    def calculate_category_summary(selected_month)
      month_start = selected_month.beginning_of_month
      month_end = selected_month.end_of_month

      # Get transactions with categories for the selected month
      transactions_with_categories = Current.user.transactions
                                              .joins(:category)
                                              .where(date: month_start..month_end)
                                              .where(transaction_type: [ "fixed_expense", "variable_expense" ])

      # Get transactions without categories for the selected month
      transactions_without_categories = Current.user.transactions
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
      Rails.logger.error "Error calculating category summary: #{e.message}"
      { categories: [], has_data: false }
    end

    def calculate_spending_trends(selected_month)
      # Get the last 6 months with actual data, starting from the selected month
      # Get months with transaction data
      months_with_data = Current.user.transactions
                                    .select(Arel.sql("DATE_TRUNC('month', date)"))
                                    .distinct
                                    .pluck(Arel.sql("DATE_TRUNC('month', date)"))
                                    .compact
                                    .sort

      # Take the last 6 months with data
      recent_months = months_with_data.first(6)

      result = recent_months.map do |month_start|
        month_end = month_start.end_of_month

        expenses = Current.user.transactions
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
      Rails.logger.error "Error calculating spending trends: #{e.message}"
      []
    end

    def calculate_monthly_stats(selected_month)
      month_start = selected_month.beginning_of_month
      month_end = selected_month.end_of_month

      transactions = Current.user.transactions.where(date: month_start..month_end)

      {
        total_transactions: transactions.count,
        income_transactions: transactions.where(transaction_type: "income").count,
        expense_transactions: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).count,
        average_income: transactions.where(transaction_type: "income").average(:amount) || 0,
        average_expense: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).average(:amount)&.abs || 0,
        largest_income: transactions.where(transaction_type: "income").maximum(:amount) || 0,
        largest_expense: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).minimum(:amount)&.abs || 0,
        top_categories: calculate_top_categories(transactions),
        has_data: transactions.any?
      }
    rescue => e
      Rails.logger.error "Error calculating monthly stats: #{e.message}"
      default_monthly_stats
    end

    private

    def calculate_top_categories(transactions)
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
      Rails.logger.error "Error calculating top categories: #{e.message}"
      []
    end

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
end
