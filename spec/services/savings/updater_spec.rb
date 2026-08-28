require "rails_helper"

RSpec.describe Savings::Updater do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:other_category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }
  # auto_sync can only be enabled once categories and accounts exist, so it is turned
  # on after the associations are assigned.
  let!(:saving) do
    create(
      :saving, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15),
      auto_sync_transactions: false, calculation_settings: { "income" => "positive" }
    ).tap do |s|
      s.category_ids = [category.id]
      s.bank_account_ids = [bank_account.id]
      s.update!(auto_sync_transactions: true)
    end
  end

  def transaction_on(date, amount: 500, category_record: category)
    create(
      :transaction, :income, user: user, bank_account: bank_account, category: category_record,
      date: date, amount: amount
    )
  end

  # The Updater rewrites associations from params on every call, exactly as the form
  # submits them, so every update carries the current ids unless it is changing them.
  def update(params)
    defaults = { category_ids: [category.id.to_s], bank_account_ids: [bank_account.id.to_s] }
    described_class.call(saving, ActionController::Parameters.new(defaults.merge(params)).permit!)
  end

  describe "moving opening_balance_date forward" do
    it "unlinks transactions the retyped balance now covers and reports the count" do
      transaction_on(Date.new(2026, 1, 20))
      expect(saving.reload.saving_transactions.count).to eq(1)

      result = update(opening_balance: "1500", opening_balance_date: "2026-01-31")

      expect(result).to be_success
      expect(saving.reload.saving_transactions.count).to eq(0)
      expect(saving.backfill_summary).to include(unlinked: 1)
    end

    it "does not double count — the balance is the retyped anchor alone" do
      transaction_on(Date.new(2026, 1, 20))

      update(opening_balance: "1500", opening_balance_date: "2026-01-31")

      expect(saving.reload.current_amount).to eq(1_500)
    end
  end

  describe "moving opening_balance_date backward" do
    it "backfills transactions that are now in reach and reports the count" do
      transaction_on(Date.new(2026, 1, 10))
      expect(saving.reload.saving_transactions.count).to eq(0)

      result = update(opening_balance_date: "2026-01-01")

      expect(result).to be_success
      expect(saving.reload.saving_transactions.count).to eq(1)
      expect(saving.backfill_summary).to include(linked: 1)
      expect(saving.current_amount).to eq(1_500)
    end
  end

  describe "eligibility changes other than the date" do
    it "backfills when a category is added" do
      transaction_on(Date.new(2026, 1, 20), category_record: other_category)

      result = update(category_ids: [category.id.to_s, other_category.id.to_s])

      expect(result).to be_success
      expect(saving.reload.saving_transactions.count).to eq(1)
      expect(saving.backfill_summary).to include(linked: 1)
    end

    it "backfills when auto-sync is turned on" do
      saving.update!(auto_sync_transactions: false)
      transaction_on(Date.new(2026, 1, 20))

      result = update(auto_sync_transactions: "1")

      expect(result).to be_success
      expect(saving.reload.saving_transactions.count).to eq(1)
      expect(saving.backfill_summary).to include(linked: 1)
    end
  end

  it "reports no summary when nothing about eligibility changed" do
    transaction_on(Date.new(2026, 1, 20))
    saving.reload.saving_transactions.destroy_all

    result = update(name: "Renamed fund")

    expect(result).to be_success
    expect(saving.reload.name).to eq("Renamed fund")
    expect(saving.backfill_summary).to be_nil
  end
  # Regression: params ran through `deep_transform_values(&:presence)`, which turns
  # false into nil. auto_sync_transactions is NOT NULL, so every mobile edit of a
  # record with auto-sync off raised a 500 rather than a validation error.
  it "accepts auto_sync_transactions: false without violating the NOT NULL constraint" do
    result = update(auto_sync_transactions: false)

    expect(result).to be_success
    expect(saving.reload.auto_sync_transactions).to be(false)
  end

  describe "a backfill that is too large to run" do
    it "reports skipped so the user is told nothing was linked" do
      stub_const("Savings::TransactionBackfiller::MAX_LINKS", 1)
      transaction_on(Date.new(2026, 1, 5))
      transaction_on(Date.new(2026, 1, 10))

      result = update(opening_balance_date: "2026-01-01")

      expect(result).to be_success
      expect(saving.backfill_summary).to include(skipped: true, linked: 0)
      expect(saving.reload.saving_transactions.count).to eq(0)
    end
  end

  # Moving the anchor forward strictly shrinks the eligible window, so nothing can
  # newly qualify — the backfill would be a guaranteed no-op query.
  it "does not run a backfill when only the date moved forward" do
    expect(Savings::TransactionBackfiller).not_to receive(:call)

    update(opening_balance: "700", opening_balance_date: "2026-01-31")
  end

  it "still backfills when the date moves forward and a category is added too" do
    expect(Savings::TransactionBackfiller).to receive(:call).and_call_original

    update(
      opening_balance: "700", opening_balance_date: "2026-01-31",
      category_ids: [category.id.to_s, other_category.id.to_s]
    )
  end
end
