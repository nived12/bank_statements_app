# frozen_string_literal: true

##
# Dashboard::DataFetcher
# Fetches all dashboard data including bank accounts, transactions, summaries, and available months
#
class Dashboard::DataFetcher < ApplicationService
  def initialize(selected_month:, user: Current.user)
    super()
    @selected_month = selected_month
    @user = user
  end

  def call
    data = aggregate_dashboard_data
    success(data)
  rescue => e
    Rails.logger.error "Dashboard data load error: #{e.message}"

    # Return graceful degradation with default values
    success(default_dashboard_data)
  end

  private

  attr_reader :selected_month, :user

  def aggregate_dashboard_data
    bank_accounts = fetch_bank_accounts
    bank_summaries = calculate_bank_summaries(bank_accounts)

    {
      available_months: calculate_available_months,
      bank_accounts: bank_accounts,
      recent_transactions: fetch_recent_transactions,
      recent_statement_files: fetch_recent_statement_files,
      monthly_summary: fetch_monthly_summary,
      category_summary: fetch_category_summary,
      spending_trends: fetch_spending_trends,
      monthly_stats: fetch_monthly_stats,
      bank_summaries: bank_summaries,
      chart_data: prepare_chart_data(bank_summaries)
    }
  end

  def fetch_bank_accounts
    user.bank_accounts.includes(:bank, :statement_files, :transactions)
        .order("banks.name")
  end

  def fetch_recent_transactions
    user.transactions.includes(:bank_account, :category)
        .order(date: :desc)
        .limit(10)
  end

  def fetch_recent_statement_files
    user.statement_files.includes(:bank_account)
        .order(created_at: :desc)
        .limit(3)
  end

  def fetch_monthly_summary
    user.calculate_monthly_summary(selected_month)
  end

  def fetch_category_summary
    user.calculate_category_summary(selected_month)
  end

  def fetch_spending_trends
    user.calculate_spending_trends(selected_month)
  end

  def fetch_monthly_stats
    user.calculate_monthly_stats(selected_month)
  end

  def calculate_bank_summaries(bank_accounts)
    bank_accounts.map do |account|
      latest_statement = account.statement_files.order(created_at: :desc).first
      latest_transaction = account.transactions.order(date: :desc).first

      {
        account: account,
        balance: calculate_account_balance(account),
        recent_activity: latest_transaction&.date || latest_statement&.created_at,
        transaction_count: account.transactions.count,
        last_processed: latest_statement&.processed_at,
        status: latest_statement&.status
      }
    end
  end

  def calculate_account_balance(account)
    # Use the new effective_balance method that respects opening balance date
    account.effective_balance
  rescue => e
    Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
    # Fallback to opening balance if effective_balance fails
    account.opening_balance || 0
  end

  def calculate_total_balance(bank_summaries)
    # Reuse already calculated balances from bank_summaries
    bank_summaries.sum { |summary| summary[:balance] || 0 }
  end

  def prepare_chart_data(bank_summaries)
    {
      spending_trends: fetch_spending_trends,
      category_summary: fetch_category_summary[:categories] || [],
      bank_summaries: format_bank_summaries_for_charts(bank_summaries)
    }
  end

  def format_bank_summaries_for_charts(bank_summaries)
    bank_summaries.map do |summary|
      {
        account: { bank_name: summary[:account].bank_display_name },
        balance: summary[:balance]
      }
    end
  end

  def calculate_available_months
    current_month = Date.current.beginning_of_month

    # Get oldest transaction month
    oldest_transaction_month = user.transactions
                                    .where.not(date: nil)
                                    .minimum(Arel.sql("DATE_TRUNC('month', date)::date"))

    # If no transactions, just return current month
    return [current_month] unless oldest_transaction_month

    # Limit to 24 months maximum (from current month going back)
    start_month = [oldest_transaction_month, 24.months.ago.beginning_of_month].max

    # Generate all months from start to current month
    available_months = []
    month = start_month
    while month <= current_month
      available_months << month
      month = month.next_month
    end

    # Sort and return unique months (newest first)
    available_months.uniq.sort.reverse
  end

  def default_dashboard_data
    {
      error: I18n.t("dashboard.data_load_error"),
      available_months: [Date.current.beginning_of_month],
      bank_accounts: [],
      recent_transactions: [],
      recent_statement_files: [],
      monthly_summary: default_monthly_summary,
      category_summary: { categories: [], has_data: false },
      spending_trends: [],
      monthly_stats: default_monthly_stats,
      bank_summaries: [],
      chart_data: default_chart_data
    }
  end

  def default_monthly_summary
    { income: 0, expenses: 0, net: 0, count: 0, has_data: false }
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

  def default_chart_data
    { spending_trends: [], category_summary: [], bank_summaries: [] }
  end

  def context_for_logging
    {
      user_id: user&.id,
      selected_month: selected_month
    }
  end
end
