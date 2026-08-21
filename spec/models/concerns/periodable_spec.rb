# frozen_string_literal: true

require "rails_helper"

RSpec.describe Periodable do
  let(:user) { create(:user) }
  let(:saving) { create(:saving, user: user, target_amount: 10000, current_amount: 0) }

  describe "#progress_for_period" do
    it "calculates progress for a given period" do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 31)

      result = saving.progress_for_period(start_date, end_date)

      expect(result).to include(:achieved, :target, :percentage, :start_date, :end_date)
      expect(result[:start_date]).to eq(start_date)
      expect(result[:end_date]).to eq(end_date)
    end
  end

  describe "#current_month_progress" do
    it "returns progress for current month" do
      result = saving.current_month_progress

      expect(result).to include(:achieved, :target, :percentage)
      expect(result[:start_date]).to eq(Date.current.beginning_of_month)
    end
  end

  describe "#monthly_timeline" do
    it "generates timeline for specified months" do
      timeline = saving.monthly_timeline(3)

      expect(timeline).to be_an(Array)
      expect(timeline.length).to be <= 3
      timeline.each do |period|
        expect(period).to include(:achieved, :target, :percentage, :month)
      end
    end

    it "does not include future months" do
      timeline = saving.monthly_timeline(24)

      future_periods = timeline.select { |p| p[:start_date] > Date.current }
      expect(future_periods).to be_empty
    end
  end

  describe "#progress_for_period respects opening_balance_date" do
    let(:user) { create(:user) }
    let(:category) { create(:category, user: user) }
    let(:bank_account) { create(:bank_account, user: user) }
    let(:saving) do
      create(
        :saving, user: user, target_amount: 10_000, opening_balance: 0,
        opening_balance_date: Date.new(2026, 3, 1)
      )
    end

    it "reports zero achieved for a month entirely before the anchor" do
      transaction = create(
        :transaction, :income, user: user, bank_account: bank_account, category: category,
        date: Date.new(2026, 2, 10), amount: 500
      )
      SavingTransaction.new(saving: saving, transaction_id: transaction.id, amount_applied: 500).tap do |link|
        link.save(validate: false) # bypass the create-time date guard to simulate a stale pre-anchor row
      end

      result = saving.progress_for_period(Date.new(2026, 2, 1), Date.new(2026, 2, 28))

      expect(result[:achieved]).to eq(0)
    end
  end
end
