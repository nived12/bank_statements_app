class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @bank_accounts = current_user.bank_accounts.includes(:statement_files)
    @recent_transactions = current_user.transactions.includes(:bank_account, :category)
                                      .order(date: :desc)
                                      .limit(10)

    # Financial summaries
    @total_balance = calculate_total_balance
    @monthly_summary = calculate_monthly_summary
    @category_summary = calculate_category_summary
    @spending_trends = calculate_spending_trends

    # Bank account summaries
    @bank_summaries = @bank_accounts.map do |account|
      {
        account: account,
        balance: calculate_account_balance(account),
        recent_activity: account.statement_files.order(created_at: :desc).first&.created_at,
        transaction_count: account.transactions.count
      }
    end
  rescue => e
    Rails.logger.error "Dashboard error: #{e.message}"
    @error = "Unable to load dashboard data. Please try again."
    @bank_accounts = []
    @recent_transactions = []
    @total_balance = 0
    @monthly_summary = { income: 0, expenses: 0, net: 0, count: 0 }
    @category_summary = []
    @spending_trends = []
    @bank_summaries = []
  end

  private

  def calculate_total_balance
    @bank_accounts.sum { |account| calculate_account_balance(account) }
  end

  def calculate_account_balance(account)
    # Get the latest statement file for this account
    latest_statement = account.statement_files.order(created_at: :desc).first

    if latest_statement&.financial_summary
      latest_statement.financial_summary.final_balance
    else
      account.opening_balance || 0
    end
  rescue => e
    Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
    account.opening_balance || 0
  end

  def calculate_monthly_summary
    current_month = Date.current.beginning_of_month
    end_of_month = Date.current.end_of_month

    transactions = current_user.transactions.where(date: current_month..end_of_month)

    {
      income: transactions.where(transaction_type: "income").sum(:amount),
      expenses: transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount),
      net: transactions.where(transaction_type: "income").sum(:amount) -
           transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount),
      count: transactions.count
    }
  rescue => e
    Rails.logger.error "Error calculating monthly summary: #{e.message}"
    { income: 0, expenses: 0, net: 0, count: 0 }
  end

  def calculate_category_summary
    current_user.transactions
                .joins(:category)
                .group("categories.name")
                .sum(:amount)
                .sort_by { |_, amount| amount.abs }
                .reverse
                .first(8)
  rescue => e
    Rails.logger.error "Error calculating category summary: #{e.message}"
    []
  end

  def calculate_spending_trends
    # Last 6 months of spending data
    (0..5).map do |month_offset|
      month_start = Date.current.beginning_of_month - month_offset.months
      month_end = month_start.end_of_month

      expenses = current_user.transactions
                            .where(date: month_start..month_end)
                            .where(transaction_type: [ "fixed_expense", "variable_expense" ])
                            .sum(:amount)

      {
        month: month_start.strftime("%b %Y"),
        amount: expenses,
        date: month_start
      }
    end.reverse
  rescue => e
    Rails.logger.error "Error calculating spending trends: #{e.message}"
    []
  end

  def ensure_user_has_categories
    current_user.ensure_default_categories
  end
end
