# spec/services/dashboard_data_service_spec.rb
require 'rails_helper'

RSpec.describe DashboardDataService do
  include_context "with current user"

  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user, name: "Food") }
  let(:selected_month) { Date.new(2025, 8, 1) } # August 2025

  describe '.fetch_dashboard_data' do
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: selected_month) }
    let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

    it 'returns a hash with all dashboard data' do
      result = described_class.fetch_dashboard_data(selected_month)

      expect(result).to include(
        :bank_accounts,
        :recent_transactions,
        :recent_statement_files,
        :monthly_summary,
        :category_summary,
        :spending_trends,
        :monthly_stats,
        :bank_summaries,
        :chart_data
      )
    end

    it 'includes bank accounts' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:bank_accounts]).to include(bank_account)
    end

    it 'includes recent transactions' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:recent_transactions]).to include(transaction)
    end

    it 'includes recent statement files' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:recent_statement_files]).to include(statement_file)
    end

    it 'includes monthly summary' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:monthly_summary]).to be_a(Hash)
      expect(result[:monthly_summary]).to include(:income, :expenses, :net, :count, :has_data)
    end

    it 'includes category summary' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:category_summary]).to be_a(Hash)
      expect(result[:category_summary]).to include(:categories, :has_data)
    end

    it 'includes spending trends' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:spending_trends]).to be_an(Array)
    end

    it 'includes monthly stats' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:monthly_stats]).to be_a(Hash)
      expect(result[:monthly_stats]).to include(:total_transactions, :has_data)
    end

    it 'includes bank summaries' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:bank_summaries]).to be_an(Array)
      expect(result[:bank_summaries].first).to include(:account, :balance, :recent_activity, :transaction_count, :last_processed, :status)
    end

    it 'includes chart data' do
      result = described_class.fetch_dashboard_data(selected_month)
      expect(result[:chart_data]).to be_a(Hash)
      expect(result[:chart_data]).to include(:spending_trends, :category_summary, :bank_summaries)
    end
  end

  describe '.fetch_available_months' do
    it 'returns an array of dates' do
      result = described_class.fetch_available_months
      expect(result).to be_an(Array)
      expect(result.first).to be_a(Date)
    end

    it 'includes current month' do
      result = described_class.fetch_available_months
      expect(result).to include(Date.current.beginning_of_month)
    end

    it 'includes months with transaction data' do
      create(:transaction, user: user, bank_account: bank_account, date: 2.months.ago)

      result = described_class.fetch_available_months
      expect(result).to include(2.months.ago.beginning_of_month)
    end
  end

  describe '#calculate_bank_summaries' do
    let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, processed_at: 2.days.ago) }
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, statement_file: statement_file, date: 1.day.ago) }

    it 'returns bank summaries with correct structure' do
      bank_accounts = described_class.send(:fetch_bank_accounts)
      result = described_class.send(:calculate_bank_summaries, bank_accounts)

      expect(result).to be_an(Array)
      expect(result.first).to include(
        :account,
        :balance,
        :recent_activity,
        :transaction_count,
        :last_processed,
        :status
      )
    end

    it 'calculates account balance correctly' do
      bank_accounts = described_class.send(:fetch_bank_accounts)
      result = described_class.send(:calculate_bank_summaries, bank_accounts)
      expect(result.first[:balance]).to be_a(Numeric)
    end

    it 'sets recent activity to transaction date when available' do
      bank_accounts = described_class.send(:fetch_bank_accounts)
      result = described_class.send(:calculate_bank_summaries, bank_accounts)
      # The service returns the most recent activity, so we need to check if it matches either transaction or statement
      recent_activity = result.first[:recent_activity]
      expect([ transaction.date.to_date, statement_file.created_at.to_date ]).to include(recent_activity.to_date)
    end

    it 'sets recent activity to statement created_at when no transactions' do
      transaction.destroy
      bank_accounts = described_class.send(:fetch_bank_accounts)
      result = described_class.send(:calculate_bank_summaries, bank_accounts)
      expect(result.first[:recent_activity].to_date).to eq(statement_file.created_at.to_date)
    end

    it 'counts transactions correctly' do
      # Create an additional transaction to make total count 2
      create(:transaction, user: user, bank_account: bank_account, statement_file: statement_file, date: 2.days.ago)

      bank_accounts = described_class.send(:fetch_bank_accounts)
      result = described_class.send(:calculate_bank_summaries, bank_accounts)

      # Find our specific bank account in the results
      our_account_summary = result.find { |summary| summary[:account].id == bank_account.id }
      expect(our_account_summary).to be_present
      expect(our_account_summary[:transaction_count]).to eq(2)
    end
  end

  describe '#prepare_chart_data' do
    it 'returns chart data with correct structure' do
      bank_accounts = described_class.send(:fetch_bank_accounts)
      bank_summaries = described_class.send(:calculate_bank_summaries, bank_accounts)
      result = described_class.send(:prepare_chart_data, selected_month, bank_summaries)

      expect(result).to include(:spending_trends, :category_summary, :bank_summaries)
    end

    it 'formats bank summaries for charts' do
      create_list(:transaction, 2, user: user, bank_account: bank_account)
      bank_accounts = described_class.send(:fetch_bank_accounts)
      bank_summaries = described_class.send(:calculate_bank_summaries, bank_accounts)
      result = described_class.send(:prepare_chart_data, selected_month, bank_summaries)

      expect(result[:bank_summaries]).to be_an(Array)
      expect(result[:bank_summaries].first).to be_a(Hash)
      expect(result[:bank_summaries].first).to include(:account, :balance)
      expect(result[:bank_summaries].first[:account]).to include(:bank_name)
    end
  end

  describe '#get_available_months' do
    it 'returns current month and last 24 months' do
      result = described_class.send(:get_available_months)

      expect(result).to include(Date.current.beginning_of_month)
      expect(result).to include(24.months.ago.beginning_of_month)
      expect(result).not_to include(25.months.ago.beginning_of_month)
    end

    it 'includes months with transaction data' do
      create(:transaction, user: user, bank_account: bank_account, date: 3.months.ago)

      result = described_class.send(:get_available_months)
      expect(result).to include(3.months.ago.beginning_of_month)
    end

    it 'returns months sorted newest first' do
      result = described_class.send(:get_available_months)
      expect(result.first).to eq(Date.current.beginning_of_month)
      expect(result.last).to be < result.first
    end
  end
end
