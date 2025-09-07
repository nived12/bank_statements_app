# spec/services/dashboard_error_handler_spec.rb
require 'rails_helper'

RSpec.describe DashboardErrorHandler do
  describe '.handle_data_load_error' do
    let(:error) { StandardError.new("Database connection failed") }

    it 'logs the error' do
      expect(Rails.logger).to receive(:error).with("Dashboard data load error: Database connection failed")
      described_class.handle_data_load_error(error)
    end

    it 'returns error data with fallback values' do
      result = described_class.handle_data_load_error(error)

      expect(result[:error]).to eq(I18n.t("dashboard.data_load_error"))
      expect(result[:bank_accounts]).to eq([])
      expect(result[:recent_transactions]).to eq([])
      expect(result[:total_balance]).to eq(0)
      expect(result[:monthly_summary]).to eq(described_class.send(:default_monthly_summary))
      expect(result[:category_summary]).to eq([])
      expect(result[:spending_trends]).to eq([])
      expect(result[:bank_summaries]).to eq([])
      expect(result[:chart_data]).to eq(described_class.send(:default_chart_data))
    end
  end


  describe '.handle_available_months_error' do
    let(:error) do
      error = StandardError.new("Query failed")
      error.set_backtrace([ "line1", "line2", "line3" ])
      error
    end

    it 'logs the error and backtrace' do
      expect(Rails.logger).to receive(:error).with("Error getting available months: Query failed")
      expect(Rails.logger).to receive(:error).with(/Backtrace:/)
      described_class.handle_available_months_error(error)
    end

    it 'returns current month as fallback' do
      result = described_class.handle_available_months_error(error)

      expect(result).to eq([ Date.current.beginning_of_month ])
    end
  end

  describe 'private methods' do
    describe '.default_monthly_summary' do
      it 'returns default monthly summary structure' do
        result = described_class.send(:default_monthly_summary)

        expect(result).to eq({
          income: 0,
          expenses: 0,
          net: 0,
          count: 0,
          has_data: false
        })
      end
    end

    describe '.default_monthly_stats' do
      it 'returns default monthly stats structure' do
        result = described_class.send(:default_monthly_stats)

        expect(result).to eq({
          total_transactions: 0,
          income_transactions: 0,
          expense_transactions: 0,
          average_income: 0,
          average_expense: 0,
          largest_income: 0,
          largest_expense: 0,
          top_categories: [],
          has_data: false
        })
      end
    end

    describe '.default_chart_data' do
      it 'returns default chart data structure' do
        result = described_class.send(:default_chart_data)

        expect(result).to eq({
          spending_trends: [],
          category_summary: [],
          bank_summaries: []
        })
      end
    end
  end
end
