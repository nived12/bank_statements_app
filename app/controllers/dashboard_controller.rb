class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @bank_accounts = current_user.bank_accounts.includes(:bank, :statement_files).order("banks.name").limit(5)
    @recent_transactions = current_user.transactions.includes(:bank_account, :category)
                                      .order(date: :desc)
                                      .limit(10)
    @recent_statement_files = current_user.statement_files.includes(:bank_account)
                                         .order(created_at: :desc)
                                         .limit(3)

    # Get selected month from params or default to current month
    @selected_month = if params[:month].present?
                        begin
                          # Parse YYYY-MM format to get the first day of the month
                          year, month = params[:month].split("-").map(&:to_i)
                          parsed_month = Date.new(year, month, 1)

                          parsed_month
                        rescue => e
                          Rails.logger.error "Error parsing month parameter: #{params[:month]} - #{e.message}"
                          Date.current.beginning_of_month
                        end
    else
                        Date.current.beginning_of_month
    end





    # Get available months with error handling
    begin
      @available_months = get_available_months

    rescue => e
      Rails.logger.error "Error getting available months: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
      @available_months = [ Date.current.beginning_of_month ]
    end

    # Financial summaries for selected month
    @monthly_summary = calculate_monthly_summary(@selected_month)
    @category_summary = calculate_category_summary(@selected_month)
    @spending_trends = calculate_spending_trends
    @total_balance = calculate_total_balance
    @total_transactions = current_user.transactions.count
    @total_statements = current_user.statement_files.count

    # Additional stats for selected month
    begin
      @monthly_stats = calculate_monthly_stats(@selected_month)
    rescue => e
      Rails.logger.error "Error calculating monthly stats: #{e.message}"
      @monthly_stats = {
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

    # Bank account summaries
    @bank_summaries = @bank_accounts.map do |account|
      latest_statement = account.statement_files.order(created_at: :desc).first
      latest_transaction = account.transactions.order(date: :desc).first

      summary = {
        account: account,
        balance: calculate_account_balance(account),
        recent_activity: latest_transaction&.date || latest_statement&.created_at,
        transaction_count: account.transactions.count,
        last_processed: latest_statement&.processed_at,
        status: latest_statement&.status
      }


      summary
    end

    # Prepare data for charts - ensure correct format
    @chart_data = {
      spending_trends: @spending_trends,
      category_summary: @category_summary[:categories] || [],
      bank_summaries: @bank_summaries.map do |summary|
        {
          account: { bank_name: summary[:account].bank_display_name },
          balance: summary[:balance]
        }
      end
    }
  rescue => e
    @error = "Unable to load dashboard data. Please try again."
    @bank_accounts = []
    @recent_transactions = []
    @total_balance = 0
    @monthly_summary = { income: 0, expenses: 0, net: 0, count: 0 }
    @category_summary = []
    @spending_trends = []
    @bank_summaries = []
    @chart_data = { spending_trends: [], category_summary: [], bank_summaries: [] }
  end

  private

  def calculate_total_balance
    @bank_accounts.sum { |account| calculate_account_balance(account) }
  end

  def calculate_account_balance(account)
    # Get the latest statement file for this account
    latest_statement = account.statement_files.order(created_at: :desc).first

    if latest_statement&.financial_summary
      # Use the financial summary
      latest_summary = latest_statement.financial_summary
      latest_summary.final_balance || latest_summary.initial_balance || 0
    else
      account.opening_balance || 0
    end
  rescue => e
    Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
    account.opening_balance || 0
  end

    def calculate_monthly_summary(selected_month)
    month_start = selected_month.beginning_of_month
    month_end = selected_month.end_of_month

    transactions = current_user.transactions.where(date: month_start..month_end)

    income = transactions.where(transaction_type: "income").sum(:amount)
    expenses = transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount)

    # Since expenses are stored as negative amounts, we need to make them positive for display
    expenses_display = expenses.abs
    net = income + expenses  # expenses are already negative, so this gives us the correct net



    {
      income: income,
      expenses: expenses_display,
      net: net,
      count: transactions.count,
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
    transactions_with_categories = current_user.transactions
                                              .joins(:category)
                                              .where(date: month_start..month_end)
                                              .where(transaction_type: [ "fixed_expense", "variable_expense" ])

    # Get transactions without categories for the selected month
    transactions_without_categories = current_user.transactions
                                                 .left_joins(:category)
                                                 .where(date: month_start..month_end)
                                                 .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                                                 .where(categories: { id: nil })

    # Group by category name and sum amounts
    result = transactions_with_categories
              .group("categories.name")
              .sum(:amount)
              .map { |category_name, amount| [ category_name, amount.abs ] }  # Make amounts positive for display

    # Add uncategorized transactions
    if transactions_without_categories.any?
      uncategorized_amount = transactions_without_categories.sum(:amount).abs
      result << [ "Sin Categorizar", uncategorized_amount ] if uncategorized_amount > 0
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

  def calculate_spending_trends
    # Get the last 6 months with actual data, starting from the selected month
    selected_month = @selected_month || Date.current.beginning_of_month

    # Get months with transaction data
    months_with_data = current_user.transactions
                                  .select(Arel.sql("DATE_TRUNC('month', date)"))
                                  .distinct
                                  .pluck(Arel.sql("DATE_TRUNC('month', date)"))
                                  .compact
                                  .sort
                                  .reverse

    # Take the last 6 months with data
    recent_months = months_with_data.first(6)

    result = recent_months.map do |month_start|
      month_end = month_start.end_of_month

      expenses = current_user.transactions
                            .where(date: month_start..month_end)
                            .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                            .sum(:amount)

      {
        month: month_start.strftime("%b %Y"),
        amount: expenses.abs,  # Make amount positive for display
        date: month_start
      }
    end

    result
  rescue => e
    Rails.logger.error "Error calculating spending trends: #{e.message}"
    []
  end

        def get_available_months
    # Start with current month
    current_month = Date.current.beginning_of_month
    available_months = [ current_month ]

    # Add last 24 months
    24.times do |i|
      month = current_month - (i + 1).months
      available_months << month
    end



    # Get months with actual transaction data
    months_with_data = current_user.transactions
                                  .select(Arel.sql("DATE_TRUNC('month', date)"))
                                  .distinct
                                  .pluck(Arel.sql("DATE_TRUNC('month', date)"))
                                  .compact

    # Add months with data
    months_with_data.each do |month|
      available_months << month unless available_months.include?(month)
    end

    # Sort and return unique months (newest first)
    available_months.uniq.sort.reverse
  end

      def calculate_monthly_stats(selected_month)
    month_start = selected_month.beginning_of_month
    month_end = selected_month.end_of_month

    transactions = current_user.transactions.where(date: month_start..month_end)

    {
      total_transactions: transactions.count,
      income_transactions: transactions.where(transaction_type: "income").count,
      expense_transactions: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).count,
      average_income: transactions.where(transaction_type: "income").average(:amount) || 0,
      average_expense: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).average(:amount)&.abs || 0,
      largest_income: transactions.where(transaction_type: "income").maximum(:amount) || 0,
      largest_expense: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).minimum(:amount)&.abs || 0,
      top_categories: begin
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
                          result << { name: "Sin Categorizar", amount: uncategorized_amount } if uncategorized_amount > 0
                        end

                        # Sort and take top 3
                        result.sort_by { |cat| cat[:amount] }.reverse.first(3)
                      rescue => e
                        Rails.logger.error "Error calculating top categories: #{e.message}"
                        []
                      end,
      has_data: transactions.any?
    }
  rescue => e
    Rails.logger.error "Error calculating monthly stats: #{e.message}"
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

  def ensure_user_has_categories
    current_user.ensure_default_categories
  end
end
