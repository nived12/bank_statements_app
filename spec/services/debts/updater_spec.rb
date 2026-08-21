require "rails_helper"

RSpec.describe Debts::Updater do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:other_category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }
  # auto_sync can only be enabled once categories and accounts exist, so it is turned
  # on after the associations are assigned.
  let!(:debt) do
    create(
      :debt, user: user, original_amount: 5_000, opening_balance: 1_000,
      opening_balance_date: Date.new(2026, 1, 15), auto_sync_transactions: false,
      calculation_settings: { "expense" => "positive" }
    ).tap do |d|
      d.category_ids = [category.id]
      d.bank_account_ids = [bank_account.id]
      d.update!(auto_sync_transactions: true)
    end
  end

  def transaction_on(date, amount: -300, category_record: category)
    create(
      :transaction, :variable_expense, user: user, bank_account: bank_account,
      category: category_record, date: date, amount: amount
    )
  end

  # The Updater rewrites associations from params on every call, exactly as the form
  # submits them, so every update carries the current ids unless it is changing them.
  def update(params)
    defaults = { category_ids: [category.id.to_s], bank_account_ids: [bank_account.id.to_s] }
    described_class.call(debt, ActionController::Parameters.new(defaults.merge(params)).permit!)
  end

  describe "moving opening_balance_date forward" do
    it "unlinks payments the retyped balance now covers and reports the count" do
      transaction_on(Date.new(2026, 1, 20))
      expect(debt.reload.debt_transactions.count).to eq(1)

      result = update(opening_balance: "700", opening_balance_date: "2026-01-31")

      expect(result).to be_success
      expect(debt.reload.debt_transactions.count).to eq(0)
      expect(debt.backfill_summary).to include(unlinked: 1)
    end

    it "does not subtract a payment twice — the balance is the retyped anchor alone" do
      transaction_on(Date.new(2026, 1, 20))

      update(opening_balance: "700", opening_balance_date: "2026-01-31")

      expect(debt.reload.current_balance).to eq(700)
    end
  end

  describe "moving opening_balance_date backward" do
    it "backfills payments that are now in reach and lowers the balance" do
      transaction_on(Date.new(2026, 1, 10))
      expect(debt.reload.debt_transactions.count).to eq(0)

      result = update(opening_balance_date: "2026-01-01")

      expect(result).to be_success
      expect(debt.reload.debt_transactions.count).to eq(1)
      expect(debt.backfill_summary).to include(linked: 1)
      expect(debt.current_balance).to eq(700)
    end
  end

  describe "eligibility changes other than the date" do
    it "backfills when a category is added" do
      transaction_on(Date.new(2026, 1, 20), category_record: other_category)

      result = update(category_ids: [category.id.to_s, other_category.id.to_s])

      expect(result).to be_success
      expect(debt.reload.debt_transactions.count).to eq(1)
      expect(debt.backfill_summary).to include(linked: 1)
    end

    it "backfills when auto-sync is turned on" do
      debt.update!(auto_sync_transactions: false)
      transaction_on(Date.new(2026, 1, 20))

      result = update(auto_sync_transactions: "1")

      expect(result).to be_success
      expect(debt.reload.debt_transactions.count).to eq(1)
      expect(debt.backfill_summary).to include(linked: 1)
    end
  end

  it "reports no summary when nothing about eligibility changed" do
    result = update(name: "Renamed debt")

    expect(result).to be_success
    expect(debt.reload.name).to eq("Renamed debt")
    expect(debt.backfill_summary).to be_nil
  end
  # Regression: params ran through `deep_transform_values(&:presence)`, which turns
  # false into nil. auto_sync_transactions is NOT NULL, so every mobile edit of a
  # record with auto-sync off raised a 500 rather than a validation error.
  it "accepts auto_sync_transactions: false without violating the NOT NULL constraint" do
    result = update(auto_sync_transactions: false)

    expect(result).to be_success
    expect(debt.reload.auto_sync_transactions).to be(false)
  end
end
