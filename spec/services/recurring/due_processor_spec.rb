# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recurring::DueProcessor do
  let(:user)         { create(:user) }
  let!(:bank_account) { create(:bank_account, user: user) }
  let(:series) do
    create(
      :recurring_series,
      user: user,
      name: "Netflix",
      expected_amount: 219.00,
      frequency: "monthly",
      transaction_type: "fixed_expense",
      next_due_date: Date.current
    )
  end

  describe "#confirm" do
    it "creates a transaction linked to the series" do
      txn = described_class.new(series).confirm
      expect(txn).to be_persisted
      expect(txn.recurring_series_id).to eq(series.id)
      expect(txn.amount).to eq(-219.00)
      expect(txn.transaction_type).to eq("fixed_expense")
    end

    it "advances next_due_date by interval_days" do
      expect { described_class.new(series).confirm }
        .to change { series.reload.next_due_date }.by(30)
    end

    it "bumps occurrences_count and sets last_charged_at" do
      described_class.new(series).confirm
      series.reload
      expect(series.occurrences_count).to eq(1)
      expect(series.last_charged_at).to eq(Date.current)
    end

    context "when the user has no bank accounts" do
      let(:bare_user) { create(:user) }
      let(:bare_series) do
        create(
          :recurring_series,
          user: bare_user,
          frequency: "monthly",
          transaction_type: "fixed_expense",
          next_due_date: Date.current
        )
      end

      it "raises NoBankAccountError without creating a transaction or advancing the date" do
        expect {
          described_class.new(bare_series).confirm
        }.to raise_error(Recurring::DueProcessor::NoBankAccountError)
        expect(Transaction.where(recurring_series_id: bare_series.id).count).to eq(0)
        expect(bare_series.reload.next_due_date).to eq(Date.current)
      end
    end

    it "uses the provided bank_account when passed explicitly" do
      other = create(:bank_account, user: user, custom_name: "Secondary")
      txn = described_class.new(series).confirm(bank_account: other)
      expect(txn.bank_account_id).to eq(other.id)
    end
  end

  describe "#skip" do
    it "advances next_due_date but does not create a transaction" do
      expect {
        described_class.new(series).skip
      }.to change { series.reload.next_due_date }.by(30)
      expect(Transaction.where(recurring_series_id: series.id).count).to eq(0)
    end
  end

  describe "#notify_if_due" do
    it "fires a push job once per day (idempotent)" do
      expect(Notifications::PushJob).to receive(:perform_later).once
      described_class.new(series).notify_if_due
      described_class.new(series.reload).notify_if_due # second call same day - skipped
    end

    it "no-ops when status is not active" do
      series.update!(status: "paused")
      expect(Notifications::PushJob).not_to receive(:perform_later)
      expect(described_class.new(series).notify_if_due).to eq(false)
    end

    it "no-ops when not yet due" do
      series.update!(next_due_date: Date.current + 1)
      expect(Notifications::PushJob).not_to receive(:perform_later)
      expect(described_class.new(series).notify_if_due).to eq(false)
    end
  end
end
