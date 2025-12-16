# frozen_string_literal: true

module Api
  module V1
    class DashboardController < BaseController
      def show
        @selected_month = parse_month_param(params[:month])

        response = Dashboard::DataFetcher.call(selected_month: @selected_month)

        if response.success?
          @dashboard_data = response.payload
          @available_months = @dashboard_data[:available_months]
          @total_balance = @dashboard_data[:bank_summaries].sum { |s| s[:balance] || 0 }
          @total_transactions = @dashboard_data[:total_transactions]
          @total_statements = @dashboard_data[:total_statements]
        else
          # Return error response
          render json: { error: response.errors.full_messages.to_sentence }, status: :internal_server_error
        end
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
