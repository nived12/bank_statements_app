# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinancialCalculations do
  include_context "with current user"

  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category1) { create(:category, user: user, name: "Food") }
  let(:category2) { create(:category, user: user, name: "Transport") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:selected_month) { Date.new(2025, 8, 1) } # August 2025

  describe "#calculate_monthly_summary" do
    context "with transactions in the selected month" do
      let!(:income_transaction) do
        create(
          :transaction, :income, user: user, bank_account: bank_account,
          statement_file: statement_file, date: selected_month + 5.days, amount: 50000.0
        )
      end
      let!(:expense_transaction) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          statement_file: statement_file, date: selected_month + 10.days, amount: -15000.0
        )
      end
      let!(:fixed_expense_transaction) do
        create(
          :transaction, :fixed_expense, user: user, bank_account: bank_account,
          statement_file: statement_file, date: selected_month + 15.days, amount: -8000.0
        )
      end

      it "calculates income correctly" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(50000.0)
      end

      it "calculates expenses correctly (as positive values)" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:expenses]).to eq(23000.0) # 15000 + 8000
      end

      it "calculates net correctly" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:net]).to eq(27000.0) # 50000 + (-15000) + (-8000)
      end

      it "counts total transactions" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:count]).to eq(3)
      end

      it "indicates data is present" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context "with transactions outside the selected month" do
      let!(:old_transaction) do
        create(
          :transaction, :income, user: user, bank_account: bank_account,
          statement_file: statement_file, date: selected_month - 1.month, amount: 10000.0
        )
      end
      let!(:future_transaction) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          statement_file: statement_file, date: selected_month + 1.month, amount: -5000.0
        )
      end

      it "excludes transactions outside the month" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end

    context "with no transactions" do
      it "returns default values" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:net]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end

    context "with investment transactions" do
      let(:investment_account) do
        create(
          :bank_account, user: user, bank: bank, account_type: "investment",
          opening_balance: 25_074.62, opening_balance_date: selected_month - 1.day
        )
      end

      let!(:matured) do
        create(
          :transaction, user: user, bank_account: investment_account,
          statement_file: statement_file, date: selected_month + 3.days,
          amount: 8_399.59, transaction_type: "investment", description: "Vencimiento de Reporto"
        )
      end
      let!(:repurchased) do
        create(
          :transaction, user: user, bank_account: investment_account,
          statement_file: statement_file, date: selected_month + 3.days,
          amount: -8_391.39, transaction_type: "investment", description: "Compra en Reporto"
        )
      end

      it "keeps investment movement out of income" do
        expect(user.calculate_monthly_summary(selected_month)[:income]).to eq(0)
      end

      it "keeps investment movement out of expenses" do
        expect(user.calculate_monthly_summary(selected_month)[:expenses]).to eq(0)
      end

      it "keeps investment movement out of net" do
        expect(user.calculate_monthly_summary(selected_month)[:net]).to eq(0)
      end

      # Why `investment` is safe as a default: the money is still in the account.
      it "still counts toward the account balance" do
        expect(investment_account.relevant_transactions).to include(matured, repurchased)
      end
    end

    context "when an error occurs" do
      before do
        allow(user).to receive(:transactions).and_raise(StandardError, "Database error")
      end

      it "handles errors gracefully" do
        result = user.calculate_monthly_summary(selected_month)
        expect(result[:income]).to eq(0)
        expect(result[:expenses]).to eq(0)
        expect(result[:net]).to eq(0)
        expect(result[:count]).to eq(0)
        expect(result[:has_data]).to be false
      end
    end
  end

  describe "#calculate_category_summary" do
    context "with categorized transactions" do
      let!(:food_transaction1) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          category: category1, date: selected_month + 5.days, amount: -1000.0
        )
      end
      let!(:food_transaction2) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          category: category1, date: selected_month + 10.days, amount: -500.0
        )
      end
      let!(:transport_transaction) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          category: category2, date: selected_month + 15.days, amount: -300.0
        )
      end

      it "groups transactions by category" do
        result = user.calculate_category_summary(selected_month)
        expect(result[:categories]).to include(a_hash_including(name: "Food", amount: 1500.0))
        expect(result[:categories]).to include(a_hash_including(name: "Transport", amount: 300.0))
      end

      it "makes amounts positive for display" do
        result = user.calculate_category_summary(selected_month)
        result[:categories].each do |cat|
          expect(cat[:amount]).to be > 0
        end
      end

      it "indicates data is present" do
        result = user.calculate_category_summary(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context "with uncategorized transactions" do
      let!(:uncategorized_transaction) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          category: nil, date: selected_month + 5.days, amount: -200.0
        )
      end

      it "includes uncategorized transactions" do
        result = user.calculate_category_summary(selected_month)
        uncategorized = result[:categories].find { |cat| cat[:name] == I18n.t("categories.uncategorized") }
        expect(uncategorized).to be_present
        expect(uncategorized[:amount]).to eq(200.0)
      end
    end

    context "with no transactions" do
      it "returns empty categories" do
        result = user.calculate_category_summary(selected_month)
        expect(result[:categories]).to eq([])
        expect(result[:has_data]).to be false
      end
    end
  end

  describe "#calculate_spending_trends" do
    context "with transactions across multiple months" do
      before do
        6.times do |i|
          month = i.months.ago.beginning_of_month
          create(
            :transaction, :variable_expense, user: user, bank_account: bank_account,
            date: month + 5.days, amount: -(1000 * (i + 1))
          )
        end
      end

      it "returns spending data for recent months" do
        result = user.calculate_spending_trends(selected_month)
        expect(result).to be_an(Array)
        expect(result.length).to be <= 6
      end

      it "includes month name and amount" do
        result = user.calculate_spending_trends(selected_month)
        result.each do |month_data|
          expect(month_data).to have_key(:month)
          expect(month_data).to have_key(:amount)
          expect(month_data).to have_key(:date)
        end
      end

      it "makes amounts positive for display" do
        result = user.calculate_spending_trends(selected_month)
        result.each do |month_data|
          expect(month_data[:amount]).to be >= 0
        end
      end
    end

    context "with no transactions" do
      it "returns empty array" do
        result = user.calculate_spending_trends(selected_month)
        expect(result).to eq([])
      end
    end
  end

  describe "#calculate_monthly_stats" do
    context "with various transaction types" do
      let!(:income1) do
        create(
          :transaction, :income, user: user, bank_account: bank_account,
          date: selected_month + 5.days, amount: 5000.0
        )
      end
      let!(:income2) do
        create(
          :transaction, :income, user: user, bank_account: bank_account,
          date: selected_month + 10.days, amount: 3000.0
        )
      end
      let!(:expense1) do
        create(
          :transaction, :variable_expense, user: user, bank_account: bank_account,
          category: category1, date: selected_month + 15.days, amount: -1000.0
        )
      end
      let!(:expense2) do
        create(
          :transaction, :fixed_expense, user: user, bank_account: bank_account,
          category: category2, date: selected_month + 20.days, amount: -500.0
        )
      end

      it "counts total transactions" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:total_transactions]).to eq(4)
      end

      it "counts income transactions" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:income_transactions]).to eq(2)
      end

      it "counts expense transactions" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:expense_transactions]).to eq(2)
      end

      it "calculates average income" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:average_income]).to eq(4000.0) # (5000 + 3000) / 2
      end

      it "calculates average expense as positive" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:average_expense]).to eq(750.0) # abs((1000 + 500) / 2)
      end

      it "finds largest income" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:largest_income]).to eq(5000.0)
      end

      it "finds largest expense as positive" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:largest_expense]).to eq(1000.0)
      end

      it "includes top categories" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:top_categories]).to be_an(Array)
        expect(result[:top_categories].length).to be <= 3
      end

      it "indicates data is present" do
        result = user.calculate_monthly_stats(selected_month)
        expect(result[:has_data]).to be true
      end
    end

    context "with no transactions" do
      it "returns default stats" do
        result = user.calculate_monthly_stats(selected_month)
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
  end
end
