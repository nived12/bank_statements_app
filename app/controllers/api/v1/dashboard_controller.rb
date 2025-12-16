# frozen_string_literal: true

module Api
  module V1
    class DashboardController < BaseController
      def show
        @selected_month = parse_month_param(params[:month])

        # Single call fetches everything
        response = Dashboard::DataFetcher.call(selected_month: @selected_month)
        @dashboard_data = response.payload

        # Extract available_months from payload (for backwards compatibility)
        @available_months = @dashboard_data[:available_months]

        # Calculate additional totals
        @total_balance = @dashboard_data[:bank_summaries].sum { |s| s[:balance] || 0 }
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
    end
  end
end
