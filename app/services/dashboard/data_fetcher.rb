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
    Rails.logger.error e.backtrace.join("\n")

    # Return failure instead of graceful degradation
    failure("Failed to load dashboard data. Please try again.")
  end

  private

  attr_reader :selected_month, :user

  def aggregate_dashboard_data
    bank_accounts = user.bank_accounts.includes(:bank, :statement_files, :transactions)
                        .order("banks.name")
    bank_summaries = calculate_bank_summaries(bank_accounts)
    spending_trends = user.calculate_spending_trends(selected_month)
    category_summary = user.calculate_category_summary(selected_month)

    {
      available_months: calculate_available_months,
      bank_accounts: bank_accounts,
      recent_transactions: user.transactions.includes(:bank_account, :category)
                              .order(date: :desc).limit(10),
      recent_statement_files: user.statement_files.includes(:bank_account)
                                 .order(created_at: :desc).limit(3),
      monthly_summary: user.calculate_monthly_summary(selected_month),
      category_summary: category_summary,
      spending_trends: spending_trends,
      monthly_stats: user.calculate_monthly_stats(selected_month),
      bank_summaries: bank_summaries,
      chart_data: {
        spending_trends: spending_trends,
        category_summary: category_summary[:categories] || [],
        bank_summaries: format_bank_summaries_for_charts(bank_summaries)
      },
      total_transactions: user.transactions.count,
      total_statements: user.statement_files.count
    }
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

  def format_bank_summaries_for_charts(bank_summaries)
    bank_summaries.map do |summary|
      {
        account: summary[:account].custom_name,
        balance: summary[:balance]
      }
    end
  end

  def context_for_logging
    {
      user_id: user&.id,
      selected_month: selected_month
    }
  end
end
