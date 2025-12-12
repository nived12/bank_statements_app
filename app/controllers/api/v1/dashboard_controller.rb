# frozen_string_literal: true

module Api
  module V1
    class DashboardController < BaseController
      def show
        @selected_month = MonthParameterService.parse_month_param(params[:month])
        @available_months = DashboardDataService.fetch_available_months
        @dashboard_data = DashboardDataService.fetch_dashboard_data(@selected_month)

        # Calculate additional totals
        @total_balance = calculate_total_balance
        @total_transactions = current_user.transactions.count
        @total_statements = current_user.statement_files.count
      end

      private

      def calculate_total_balance
        @dashboard_data[:bank_accounts].sum { |account| calculate_account_balance(account) }
      end

      def calculate_account_balance(account)
        balance = account.effective_balance
        balance || 0
      rescue StandardError => e
        Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
        account.opening_balance || 0
      end
    end
  end
end
