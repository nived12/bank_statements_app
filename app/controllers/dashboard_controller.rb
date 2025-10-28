class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @selected_month = MonthParameterService.parse_month_param(params[:month])
    @available_months = fetch_available_months

    # Load dashboard layout preferences
    @widgets = current_user.enabled_dashboard_widgets

    # Fetch dashboard data
    dashboard_data = fetch_dashboard_data(@selected_month)

    # Assign instance variables from the service response
    assign_dashboard_variables(dashboard_data)

    # Calculate additional totals
    @total_balance = calculate_total_balance
    @total_transactions = current_user.transactions.count
    @total_statements = current_user.statement_files.count

    respond_to do |format|
      format.html
      format.json
    end
  rescue => e
    error_data = DashboardErrorHandler.handle_data_load_error(e)
    assign_dashboard_variables(error_data)

    respond_to do |format|
      format.html
      format.json { render json: { error: @error }, status: :unprocessable_entity }
    end
  end

  def update_layout
    widgets = JSON.parse(params[:widgets] || "[]")

    begin
      current_user.update_dashboard_widgets!(widgets)
      render json: { success: true, message: "Dashboard updated successfully" }
    rescue ArgumentError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Error updating dashboard layout: #{e.message}"
      render json: { success: false, error: "Failed to update dashboard" }, status: :internal_server_error
    end
  end

  private

  def fetch_dashboard_data(selected_month)
    cache_key = "dashboard/#{current_user.id}/#{selected_month.strftime("%Y-%m")}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      DashboardDataService.fetch_dashboard_data(selected_month)
    end
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
    account.effective_balance
  rescue => e
    Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
    account.opening_balance || 0
  end

  def ensure_user_has_categories
    current_user.ensure_default_categories
  end
end
