# spec/services/financial_calculation_service_spec.rb
require 'rails_helper'

RSpec.describe FinancialCalculationService do
  include_context "with current user"

  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category1) { create(:category, user: user, name: "Food") }
  let(:category2) { create(:category, user: user, name: "Transport") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:selected_month) { Date.new(2025, 8, 1) } # August 2025

  describe '.calculate_monthly_summary' do
    context 'with transactions in the selected month' do
      let!(:income_transaction) do
        create(:transaction, :income, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: 50000.0)
      end
      let!(:expense_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 10.days, amount: -15000.0)
      end
      let!(:fixed_expense_transaction) do
        create(:transaction, :fixed_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 15.days, amount: -8000.0)
      end

      it 'calculates income correctly' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(50000.0)
      end

      it 'calculates expenses correctly (as positive values)' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:expenses]).to eq(23000.0) # 15000 + 8000
      end

      it 'calculates net correctly' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:net]).to eq(27000.0) # 50000 + (-15000) + (-8000)
      end

      it 'counts total transactions' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:count]).to eq(3)
      end

      it 'indicates data is present' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context 'with transactions outside the selected month' do
      let!(:old_transaction) do
        create(:transaction, :income, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month - 1.month, amount: 10000.0)
      end
      let!(:future_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 1.month, amount: -5000.0)
      end

      it 'excludes transactions outside the month' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end

    context 'with no transactions' do
      it 'returns default values' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:net]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end

    context 'when an error occurs' do
      before do
        allow(Current.user).to receive(:transactions).and_raise(StandardError, "Database error")
      end

      it 'handles errors gracefully' do
        result = described_class.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:net]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end
  end

  describe '.calculate_category_summary' do
    context 'with categorized transactions' do
      let!(:food_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: -20000.0, category: category1)
      end
      let!(:transport_transaction) do
        create(:transaction, :fixed_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 10.days, amount: -15000.0, category: category2)
      end

      it 'groups transactions by category' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories]).to contain_exactly(
          [ "Food", 20000.0 ],
          [ "Transport", 15000.0 ]
        )
      end

      it 'sorts categories by amount (highest first)' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories].first[1]).to eq(20000.0) # Food (highest)
        expect(result[:categories].last[1]).to eq(15000.0)  # Transport (lowest)
      end

      it 'indicates data is present' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context 'with uncategorized transactions' do
      let!(:uncategorized_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: -10000.0, category: nil)
      end

      it 'includes uncategorized transactions' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories]).to contain_exactly(
          [ I18n.t("categories.uncategorized"), 10000.0 ]
        )
      end
    end

    context 'with mixed categorized and uncategorized transactions' do
      let!(:categorized_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: -25000.0, category: category1)
      end
      let!(:uncategorized_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 10.days, amount: -15000.0, category: nil)
      end

      it 'combines both types correctly' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories]).to contain_exactly(
          [ "Food", 25000.0 ],
          [ I18n.t("categories.uncategorized"), 15000.0 ]
        )
      end
    end

    context 'with more than 8 categories' do
      before do
        10.times do |i|
          category = create(:category, user: user, name: "Category #{i}")
          create(:transaction, :variable_expense, user: user, bank_account: bank_account,
                 statement_file: statement_file, date: selected_month + i.days, amount: -(1000.0 * (i + 1)), category: category)
        end
      end

      it 'limits results to top 8 categories' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories].length).to eq(8)
      end
    end

    context 'when an error occurs' do
      before do
        allow(Current.user).to receive(:transactions).and_raise(StandardError, "Database error")
      end

      it 'handles errors gracefully' do
        result = described_class.calculate_category_summary(selected_month)
        expect(result[:categories]).to eq([])
        expect(result[:has_data]).to be false
      end
    end
  end

  describe '.calculate_spending_trends' do
    context 'with transactions across multiple months' do
      let!(:august_expense) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: Date.new(2025, 8, 15), amount: -20000.0)
      end
      let!(:july_expense) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: Date.new(2025, 7, 15), amount: -15000.0)
      end
      let!(:june_expense) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: Date.new(2025, 6, 15), amount: -10000.0)
      end

      it 'returns spending trends for months with data' do
        result = described_class.calculate_spending_trends(selected_month)
        expect(result).to be_an(Array)
        expect(result.length).to be <= 6
      end

      it 'formats month names correctly' do
        result = described_class.calculate_spending_trends(selected_month)
        expect(result.first[:month]).to match(/^[A-Za-z]{3} \d{4}$/)
      end

      it 'calculates amounts as positive values' do
        result = described_class.calculate_spending_trends(selected_month)
        result.each do |trend|
          expect(trend[:amount]).to be >= 0
        end
      end

      it 'includes date information' do
        result = described_class.calculate_spending_trends(selected_month)
        result.each do |trend|
          expect(trend[:date]).to be_a(Time)
        end
      end
    end

    context 'with no transaction data' do
      it 'returns empty array' do
        result = described_class.calculate_spending_trends(selected_month)
        expect(result).to eq([])
      end
    end

    context 'when an error occurs' do
      before do
        allow(Current.user).to receive(:transactions).and_raise(StandardError, "Database error")
      end

      it 'handles errors gracefully' do
        result = described_class.calculate_spending_trends(selected_month)
        expect(result).to eq([])
      end
    end
  end

  describe '.calculate_monthly_stats' do
    context 'with various transaction types' do
      let!(:income_transaction) do
        create(:transaction, :income, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: 100000.0)
      end
      let!(:large_expense) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 10.days, amount: -50000.0, category: category1)
      end
      let!(:small_expense) do
        create(:transaction, :fixed_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 15.days, amount: -10000.0, category: category2)
      end

      it 'counts total transactions' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:total_transactions]).to eq(3)
      end

      it 'counts income transactions' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:income_transactions]).to eq(1)
      end

      it 'counts expense transactions' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:expense_transactions]).to eq(2)
      end

      it 'calculates average income' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:average_income]).to eq(100000.0)
      end

      it 'calculates average expense (as positive value)' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:average_expense]).to eq(30000.0) # (50000 + 10000) / 2
      end

      it 'finds largest income' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:largest_income]).to eq(100000.0)
      end

      it 'finds largest expense (as positive value)' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:largest_expense]).to eq(50000.0)
      end

      it 'indicates data is present' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context 'with top categories' do
      let!(:food_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 5.days, amount: -30000.0, category: category1)
      end
      let!(:transport_transaction) do
        create(:transaction, :variable_expense, user: user, bank_account: bank_account,
               statement_file: statement_file, date: selected_month + 10.days, amount: -20000.0, category: category2)
      end

      it 'includes top categories' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:top_categories]).to be_an(Array)
        expect(result[:top_categories].length).to eq(2)
        expect(result[:top_categories].first[:name]).to eq("Food")
        expect(result[:top_categories].first[:amount]).to eq(30000.0)
      end
    end

    context 'with no transactions' do
      it 'returns default stats' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:total_transactions]).to eq(0)
        expect(result[:income_transactions]).to eq(0)
        expect(result[:expense_transactions]).to eq(0)
        expect(result[:average_income]).to eq(0)
        expect(result[:average_expense]).to eq(0)
        expect(result[:largest_income]).to eq(0)
        expect(result[:largest_expense]).to eq(0)
        expect(result[:top_categories]).to eq([])
        expect(result[:has_data]).to be false
      end
    end

    context 'when an error occurs' do
      before do
        allow(Current.user).to receive(:transactions).and_raise(StandardError, "Database error")
      end

      it 'handles errors gracefully' do
        result = described_class.calculate_monthly_stats(selected_month)
        expect(result[:total_transactions]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end
  end

  describe 'private methods' do
    describe '#calculate_top_categories' do
      let(:transactions) { user.transactions.where(date: selected_month.beginning_of_month..selected_month.end_of_month) }

      context 'with categorized transactions' do
        let!(:food_transaction) do
          create(:transaction, :variable_expense, user: user, bank_account: bank_account,
                 statement_file: statement_file, date: selected_month + 5.days, amount: -25000.0, category: category1)
        end

        it 'calculates top categories correctly' do
          result = described_class.send(:calculate_top_categories, transactions)
          expect(result).to contain_exactly(
            { name: "Food", amount: 25000.0 }
          )
        end
      end

      context 'with uncategorized transactions' do
        let!(:uncategorized_transaction) do
          create(:transaction, :variable_expense, user: user, bank_account: bank_account,
                 statement_file: statement_file, date: selected_month + 5.days, amount: -15000.0, category: nil)
        end

        it 'includes uncategorized transactions' do
          result = described_class.send(:calculate_top_categories, transactions)
          expect(result).to contain_exactly(
            { name: I18n.t("categories.uncategorized"), amount: 15000.0 }
          )
        end
      end

      context 'with more than 3 categories' do
        before do
          5.times do |i|
            category = create(:category, user: user, name: "Category #{i}")
            create(:transaction, :variable_expense, user: user, bank_account: bank_account,
                   statement_file: statement_file, date: selected_month + i.days, amount: -(1000.0 * (i + 1)), category: category)
          end
        end

        it 'limits results to top 3 categories' do
          result = described_class.send(:calculate_top_categories, transactions)
          expect(result.length).to eq(3)
        end
      end

      context 'when an error occurs' do
        before do
          allow(transactions).to receive(:joins).and_raise(StandardError, "Database error")
        end

        it 'handles errors gracefully' do
          result = described_class.send(:calculate_top_categories, transactions)
          expect(result).to eq([])
        end
      end
    end

    describe '#default_monthly_stats' do
      it 'returns default structure' do
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
  end
end
