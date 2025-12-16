class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @selected_month = parse_month_param(params[:month])

    # Single call fetches everything
    response = Dashboard::DataFetcher.call(selected_month: @selected_month)
    data = response.payload

    # Extract available_months from payload
    @available_months = data[:available_months]

    # Assign other dashboard variables
    assign_dashboard_variables(data)

    # Calculate additional totals
    @total_balance = calculate_total_balance
    @total_transactions = Current.user.transactions.count
    @total_statements = Current.user.statement_files.count
  end

  private

  def parse_month_param(month_param)
    return Date.current.beginning_of_month unless month_param.present?

    Date.strptime(month_param, "%Y-%m")
  rescue ArgumentError, Date::Error
    Date.current.beginning_of_month
  end

  def assign_dashboard_variables(data)
    @bank_accounts = data[:bank_accounts]
    @recent_transactions = data[:recent_transactions]
    @recent_statement_files = data[:recent_statement_files]
    @monthly_summary = data[:monthly_summary]
    @category_summary = data[:category_summary]
    @spending_trends = data[:spending_trends]
    @monthly_stats = data[:monthly_stats]
    @bank_summaries = data[:bank_summaries]
    @chart_data = data[:chart_data]
    @error = data[:error] if data[:error]
  end

  def calculate_total_balance
    @bank_accounts.sum { |account| calculate_account_balance(account) }
  end

  def calculate_account_balance(account)
    # Use the new effective_balance method that respects opening balance date
    balance = account.effective_balance
    # Ensure we always return a number, never nil
    balance || 0
  rescue => e
    Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
    # Fallback to opening balance if effective_balance fails
    account.opening_balance || 0
  end

  def ensure_user_has_categories
    current_user.ensure_default_categories
  end
end
