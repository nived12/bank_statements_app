class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @selected_month = MonthParameterService.parse_month_param(params[:month])
    @available_months = fetch_available_months

    # Use fragment caching with cache key based on user and month
    cache_key = "dashboard/#{current_user.id}/#{@selected_month.strftime("%Y-%m")}"

    @dashboard_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      fetch_dashboard_data(@selected_month)
    end

    # Assign instance variables from the service response
    assign_dashboard_variables(@dashboard_data)

    # Calculate additional totals
    @total_balance = calculate_total_balance
    @total_transactions = current_user.transactions.count
    @total_statements = current_user.statement_files.count

  rescue => e
    error_data = DashboardErrorHandler.handle_data_load_error(e)
    assign_dashboard_variables(error_data)
  end

  private

  def fetch_dashboard_data(selected_month)
    DashboardDataService.fetch_dashboard_data(selected_month)
  end

  def fetch_available_months
    DashboardDataService.fetch_available_months
  rescue => e
    DashboardErrorHandler.handle_available_months_error(e)
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
