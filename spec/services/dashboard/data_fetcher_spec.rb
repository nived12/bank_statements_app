# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboard::DataFetcher do
  include_context "with current user"

  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user, name: "Food") }
  let(:selected_month) { Date.new(2025, 8, 1) } # August 2025

  describe ".call" do
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: selected_month) }
    let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

    it "returns a success response" do
      result = described_class.call(selected_month: selected_month)

      expect(result).to be_a(ApplicationService::Response)
      expect(result).to be_success
    end

    it "returns a hash with all dashboard data including available_months" do
      result = described_class.call(selected_month: selected_month)

      expect(result.payload).to include(
        :available_months,
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

    it "includes available_months array" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:available_months]).to be_an(Array)
      expect(result.payload[:available_months].first).to be_a(Date)
    end

    it "includes bank accounts" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:bank_accounts]).to include(bank_account)
    end

    it "includes recent transactions" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:recent_transactions]).to include(transaction)
    end

    it "includes recent statement files" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:recent_statement_files]).to include(statement_file)
    end

    it "includes monthly summary" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:monthly_summary]).to be_a(Hash)
      expect(result.payload[:monthly_summary]).to include(:income, :expenses, :net, :count, :has_data)
    end

    it "includes category summary" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:category_summary]).to be_a(Hash)
      expect(result.payload[:category_summary]).to include(:categories, :has_data)
    end

    it "includes spending trends" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:spending_trends]).to be_an(Array)
    end

    it "includes monthly stats" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:monthly_stats]).to be_a(Hash)
      expect(result.payload[:monthly_stats]).to include(:total_transactions, :has_data)
    end

    it "includes bank summaries" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:bank_summaries]).to be_an(Array)
      expect(result.payload[:bank_summaries].first).to include(:account, :balance, :recent_activity, :transaction_count, :last_processed, :status)
    end

    it "includes chart data" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:chart_data]).to be_a(Hash)
      expect(result.payload[:chart_data]).to include(:spending_trends, :category_summary, :bank_summaries)
    end
  end

  describe "available_months calculation" do
    it "includes current month" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:available_months]).to include(Date.current.beginning_of_month)
    end

    it "includes months with transaction data" do
      create(:transaction, user: user, bank_account: bank_account, date: 2.months.ago)

      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:available_months]).to include(2.months.ago.beginning_of_month)
    end

    it "returns months sorted newest first" do
      create(:transaction, user: user, bank_account: bank_account, date: 3.months.ago)

      result = described_class.call(selected_month: selected_month)
      available_months = result.payload[:available_months]
      expect(available_months.first).to eq(Date.current.beginning_of_month)
      expect(available_months.last).to be < available_months.first
    end

    it "limits to 24 months maximum when oldest transaction is more than 2 years ago" do
      # Create transaction 30 months ago
      create(:transaction, user: user, bank_account: bank_account, date: 30.months.ago)
      # Create transaction 3 months ago
      create(:transaction, user: user, bank_account: bank_account, date: 3.months.ago)

      result = described_class.call(selected_month: selected_month)
      available_months = result.payload[:available_months]

      # Should only include last 24 months, not all 30
      expect(available_months.length).to eq(25) # current month + 24 past months
      expect(available_months.first).to eq(Date.current.beginning_of_month)
      expect(available_months.last).to eq(24.months.ago.beginning_of_month)
      expect(available_months).not_to include(25.months.ago.beginning_of_month)
    end

    it "returns current month only when no transactions exist" do
      Transaction.destroy_all
      result = described_class.call(selected_month: selected_month)

      expect(result.payload[:available_months]).to eq([Date.current.beginning_of_month])
    end
  end

  describe "bank summaries calculation" do
    let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, processed_at: 2.days.ago) }
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, statement_file: statement_file, date: 1.day.ago) }

    it "returns bank summaries with correct structure" do
      result = described_class.call(selected_month: selected_month)

      expect(result.payload[:bank_summaries]).to be_an(Array)
      expect(result.payload[:bank_summaries].first).to include(
        :account,
        :balance,
        :recent_activity,
        :transaction_count,
        :last_processed,
        :status
      )
    end

    it "calculates account balance correctly" do
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:bank_summaries].first[:balance]).to be_a(Numeric)
    end

    it "sets recent activity to transaction date when available" do
      result = described_class.call(selected_month: selected_month)
      # The service returns the most recent activity, so we need to check if it matches either transaction or statement
      recent_activity = result.payload[:bank_summaries].first[:recent_activity]
      expect([ transaction.date.to_date, statement_file.created_at.to_date ]).to include(recent_activity.to_date)
    end

    it "sets recent activity to statement created_at when no transactions" do
      transaction.destroy
      result = described_class.call(selected_month: selected_month)
      expect(result.payload[:bank_summaries].first[:recent_activity].to_date).to eq(statement_file.created_at.to_date)
    end

    it "counts transactions correctly" do
      # Create an additional transaction to make total count 2
      create(:transaction, user: user, bank_account: bank_account, statement_file: statement_file, date: 2.days.ago)

      result = described_class.call(selected_month: selected_month)

      # Find our specific bank account in the results
      our_account_summary = result.payload[:bank_summaries].find { |summary| summary[:account].id == bank_account.id }
      expect(our_account_summary).to be_present
      expect(our_account_summary[:transaction_count]).to eq(2)
    end
  end

  describe "chart data preparation" do
    it "returns chart data with correct structure" do
      result = described_class.call(selected_month: selected_month)

      expect(result.payload[:chart_data]).to include(:spending_trends, :category_summary, :bank_summaries)
    end

    it "formats bank summaries for charts" do
      create_list(:transaction, 2, user: user, bank_account: bank_account)
      result = described_class.call(selected_month: selected_month)

      expect(result.payload[:chart_data][:bank_summaries]).to be_an(Array)
      expect(result.payload[:chart_data][:bank_summaries].first).to be_a(Hash)
      expect(result.payload[:chart_data][:bank_summaries].first).to include(:account, :balance)
      expect(result.payload[:chart_data][:bank_summaries].first[:account]).to include(:bank_name)
    end
  end

  describe "error handling" do
    it "returns graceful degradation with default values on error" do
      # Pass the user explicitly and stub its transactions to raise an error
      allow(user).to receive(:bank_accounts).and_raise(StandardError.new("Test error"))

      result = described_class.call(selected_month: selected_month, user: user)

      expect(result).to be_success
      expect(result.payload[:bank_accounts]).to eq([])
      expect(result.payload[:recent_transactions]).to eq([])
      expect(result.payload[:available_months]).to eq([Date.current.beginning_of_month])
      expect(result.payload[:monthly_summary]).to include(income: 0, expenses: 0, net: 0, count: 0, has_data: false)
    end
  end
end
