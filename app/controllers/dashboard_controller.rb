class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :ensure_user_has_categories

  def index
    @selected_month = parse_month_param(params[:month])

    response = Dashboard::DataFetcher.call(selected_month: @selected_month)

    if response.success?
      data = response.payload
      @available_months = data[:available_months]
      assign_dashboard_variables(data)
      @total_balance = data[:bank_summaries].sum { |s| s[:balance] || 0 }
      @total_transactions = data[:total_transactions]
      @total_statements = data[:total_statements]
    else
      # Set default empty data
      @error = response.errors.full_messages.to_sentence
      @available_months = [Date.current.beginning_of_month]
      @bank_accounts = []
      @recent_transactions = []
      @recent_statement_files = []
      @monthly_summary = { income: 0, expenses: 0, net: 0, count: 0, has_data: false }
      @category_summary = { categories: [], has_data: false }
      @spending_trends = []
      @monthly_stats = { total_transactions: 0, has_data: false }
      @bank_summaries = []
      @chart_data = { spending_trends: [], category_summary: [], bank_summaries: [] }
      @total_balance = 0
      @total_transactions = 0
      @total_statements = 0
    end
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
  end

  def ensure_user_has_categories
    current_user.ensure_default_categories
  end
end
