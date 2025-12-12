# frozen_string_literal: true

module Api
  module V1
    class DashboardController < BaseController
      def show
        @selected_month = parse_month_param(params[:month])
        @available_months = DashboardDataService.fetch_available_months
        @dashboard_data = DashboardDataService.fetch_dashboard_data(@selected_month)

        # Calculate additional totals
        @total_balance = calculate_total_balance
        @total_transactions = current_user.transactions.count
        @total_statements = current_user.statement_files.count
      end

      private

      def parse_month_param(month_param)
        return Date.current.beginning_of_month unless month_param.present?

        Date.strptime(month_param, "%Y-%m")
      rescue ArgumentError, Date::Error
        Date.current.beginning_of_month
      end

      def calculate_total_balance
        # Delegate to service for consistency
        DashboardDataService.send(:calculate_total_balance, @dashboard_data[:bank_summaries])
      end
    end
  end
end
