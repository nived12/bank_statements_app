# app/services/dashboard_error_handler.rb
class DashboardErrorHandler
  class << self
    def handle_data_load_error(error)
      Rails.logger.error "Dashboard data load error: #{error.message}"

      {
        error: I18n.t("dashboard.data_load_error"),
        bank_accounts: [],
        recent_transactions: [],
        total_balance: 0,
        monthly_summary: default_monthly_summary,
        category_summary: [],
        spending_trends: [],
        bank_summaries: [],
        chart_data: default_chart_data
      }
    end


    def handle_available_months_error(error)
      Rails.logger.error "Error getting available months: #{error.message}"
      if error.backtrace
        Rails.logger.error "Backtrace: #{error.backtrace.first(3).join("\n")}"
      end
      [ Date.current.beginning_of_month ]
    end

    private

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
  end
end
