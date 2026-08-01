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

    describe "overdue throttling" do
      # next_due_date only advances on confirm/skip, so an ignored series stays
      # "due" forever. These bound the reminders.

      it "does not renotify the next day" do
        series.update!(next_due_date: Date.current - 1, last_notified_on: Date.current - 1)
        expect(Notifications::PushJob).not_to receive(:perform_later)
        expect(described_class.new(series).notify_if_due).to eq(false)
      end

      it "renotifies once RENOTIFY_AFTER_DAYS has passed" do
        series.update!(
          next_due_date: Date.current - 5,
          last_notified_on: Date.current - described_class::RENOTIFY_AFTER_DAYS - 1
        )
        expect(Notifications::PushJob).to receive(:perform_later).once
        expect(described_class.new(series).notify_if_due).to eq(true)
      end

      it "stops entirely once the series is abandoned" do
        series.update!(
          next_due_date: Date.current - described_class::ABANDONED_AFTER_DAYS - 1,
          last_notified_on: nil
        )
        expect(Notifications::PushJob).not_to receive(:perform_later)
        expect(described_class.new(series).notify_if_due).to eq(false)
      end

      it "sends a bounded number of reminders instead of one per day" do
        # Simulates the daily job across 40 days on a series the user ignores.
        series.update!(next_due_date: Date.current, last_notified_on: nil)
        sent = 0
        allow(Notifications::PushJob).to receive(:perform_later) { sent += 1 }

        40.times do |day|
          travel_to(Date.current + day) { described_class.new(series.reload).notify_if_due }
        end

        # Pre-fix this was 40 (one every single day, forever).
        expect(sent).to be_between(1, 12)
      end
    end

    describe "copy" do
      it "says due today when due today" do
        series.update!(next_due_date: Date.current)
        expect(Notifications::PushJob).to receive(:perform_later)
          .with(hash_including(title: I18n.t("recurring.notifications.due_title", name: series.name)))
        described_class.new(series).notify_if_due
      end

      it "does not claim 'today' for an overdue series" do
        series.update!(next_due_date: Date.current - 4, last_notified_on: nil)
        expect(Notifications::PushJob).to receive(:perform_later) do |args|
          expect(args[:title]).to eq(I18n.t("recurring.notifications.overdue_title", name: series.name))
          expect(args[:body]).to include("4")
        end
        described_class.new(series).notify_if_due
      end
    end
  end
end
