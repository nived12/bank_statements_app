# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recurring::Detector do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }

  def make_txn(description:, amount:, date:, merchant: nil, type: "variable_expense")
    create(
      :transaction,
      user: user,
      bank_account: bank_account,
      description: description,
      amount: amount,
      date: date,
      merchant: merchant,
      transaction_type: type,
      statement_file: nil,
      category: nil
    )
  end

  describe "#call" do
    context "Netflix-style monthly subscription" do
      before do
        5.times do |i|
          make_txn(
            description: "NETFLIX.COM 866-579-7172 CA",
            amount: -219.00,
            date: Date.current - (5 - i) * 30,
            merchant: "Netflix",
            type: "fixed_expense"
          )
        end
      end

      it "creates a detected series with high confidence" do
        series = described_class.new(user).call
        expect(series.size).to eq(1)
        expect(series.first.status).to eq("detected")
        expect(series.first.frequency).to eq("monthly")
        expect(series.first.confidence_score).to be >= 80
        expect(series.first.expected_amount).to eq(219.00)
      end

      it "backfills recurring_series_id on past transactions" do
        described_class.new(user).call
        expect(user.transactions.where.not(recurring_series_id: nil).count).to eq(5)
      end
    end

    context "Amazon-style variable purchases" do
      before do
        # Same merchant-ish text, wildly different amounts, random dates
        [["Amazon Mktp US*1A2B3", -45.99, 10],
         ["AMZN MKTP US",          -312.50, 18],
         ["Amazon.com",             -19.00, 27],
         ["Amazon Mktp",            -899.00, 31],
         ["AMZN MKTP",              -7.50,  44]].each do |desc, amt, days_ago|
          make_txn(description: desc, amount: amt, date: Date.current - days_ago.days)
        end
      end

      it "does NOT create a recurring series" do
        series = described_class.new(user).call
        expect(series).to be_empty
      end
    end

    context "Quarterly insurance payment" do
      before do
        4.times do |i|
          make_txn(
            description: "AXA SEGUROS POLIZA 12345",
            amount: -3500.00,
            date: Date.current - (4 - i) * 91,
            type: "fixed_expense"
          )
        end
      end

      it "detects with quarterly cadence" do
        series = described_class.new(user).call
        expect(series.size).to eq(1)
        expect(series.first.frequency).to eq("quarterly")
      end
    end

    context "Rent with consistent monthly cadence" do
      before do
        6.times do |i|
          make_txn(
            description: "RENTA DEPARTAMENTO POLANCO",
            amount: -25000.00,
            date: Date.current - (6 - i) * 30,
            type: "fixed_expense"
          )
        end
      end

      it "detects with score ≥ 85" do
        series = described_class.new(user).call
        expect(series.size).to eq(1)
        expect(series.first.confidence_score).to be >= 85
      end
    end

    context "Gym with price bump within tolerance" do
      before do
        # 3 months at 800, 2 months at 850 — CV ~3%, well below 15%
        [800, 800, 800, 850, 850].each_with_index do |amt, i|
          make_txn(
            description: "SMART FIT MEXICO",
            amount: -amt,
            date: Date.current - (5 - i) * 30,
            type: "fixed_expense"
          )
        end
      end

      it "still detects despite minor amount drift" do
        series = described_class.new(user).call
        expect(series.size).to eq(1)
      end
    end

    context "Only 2 occurrences" do
      before do
        2.times do |i|
          make_txn(
            description: "SPOTIFY PREMIUM",
            amount: -199.00,
            date: Date.current - (2 - i) * 30
          )
        end
      end

      it "does not detect (below MIN_OCCURRENCES)" do
        expect(described_class.new(user).call).to be_empty
      end
    end

    context "occurrences too close together (under MIN_SPAN_DAYS)" do
      before do
        3.times do |i|
          make_txn(
            description: "TEST SUB",
            amount: -100.00,
            date: Date.current - i.days
          )
        end
      end

      it "does not detect" do
        expect(described_class.new(user).call).to be_empty
      end
    end

    context "transactions already linked to a series" do
      let!(:existing_series) { create(:recurring_series, user: user) }

      before do
        5.times do |i|
          make_txn(
            description: "NETFLIX",
            amount: -219.00,
            date: Date.current - (5 - i) * 30
          ).update!(recurring_series: existing_series)
        end
      end

      it "skips linked transactions" do
        expect(described_class.new(user).call).to be_empty
      end
    end

    context "idempotency — re-running does not create duplicates" do
      before do
        5.times do |i|
          make_txn(
            description: "NETFLIX",
            amount: -219.00,
            date: Date.current - (5 - i) * 30,
            type: "fixed_expense"
          )
        end
        described_class.new(user).call
      end

      it "running again returns the same series" do
        Transaction.where(user: user).update_all(recurring_series_id: nil)
        result = described_class.new(user).call
        expect(user.recurring_series.count).to eq(1)
        expect(result.first.id).to eq(user.recurring_series.first.id)
      end
    end

    context "when a concurrent run persists the same signature first" do
      before do
        5.times do |i|
          make_txn(
            description: "NETFLIX",
            amount: -219.00,
            date: Date.current - (5 - i) * 30,
            type: "fixed_expense"
          )
        end
      end

      it "rescues ActiveRecord::RecordNotUnique and returns the already-persisted series" do
        # Pre-create the winner row to simulate another worker having persisted it first.
        create(
          :recurring_series,
          user: user,
          name: "NETFLIX",
          description_signature: "netflix",
          frequency: "monthly",
          transaction_type: "fixed_expense"
        )

        # Force the next save! to raise the uniqueness violation; subsequent retries
        # call the original (which is a successful update of the existing row).
        raised = false
        allow_any_instance_of(RecurringSeries).to receive(:save!).and_wrap_original do |original, *args|
          if !raised
            raised = true
            raise ActiveRecord::RecordNotUnique, "unique violation (simulated)"
          end

          original.call(*args)
        end

        expect { described_class.new(user).call }.not_to raise_error
        expect(user.recurring_series.where(description_signature: "netflix").count).to eq(1)
      end
    end
  end
end
