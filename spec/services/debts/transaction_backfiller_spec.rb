require "rails_helper"

RSpec.describe Debts::TransactionBackfiller do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let!(:debt) do
    create(
      :debt, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15),
      auto_sync_transactions: false, calculation_settings: { "expense" => "positive" }
    ).tap do |d|
      d.category_ids = [category.id]
      d.bank_account_ids = [bank_account.id]
    end
  end

  def transaction_on(date, amount: -300)
    create(
      :transaction, :variable_expense, user: user, bank_account: bank_account, category: category,
      date: date, amount: amount
    )
  end

  it "links pre-existing matching transactions dated after opening_balance_date" do
    before_cutoff = transaction_on(Date.new(2026, 1, 10))
    after_cutoff = transaction_on(Date.new(2026, 1, 16))
    debt.update!(auto_sync_transactions: true)

    result = described_class.call(debt)

    expect(result).to be_success
    expect(result.payload).to eq(linked: 1, skipped: false)
    expect(DebtTransaction.find_by(transaction_id: after_cutoff.id)).to be_present
    expect(DebtTransaction.find_by(transaction_id: before_cutoff.id)).to be_nil
    expect(debt.reload.current_balance).to eq(700)
  end

  it "is idempotent — a second run links nothing new" do
    transaction_on(Date.new(2026, 1, 16))
    debt.update!(auto_sync_transactions: true)
    described_class.call(debt)

    result = described_class.call(debt)

    expect(result.payload).to eq(linked: 0, skipped: false)
    expect(DebtTransaction.count).to eq(1)
  end

  it "refuses to run when candidates exceed MAX_LINKS" do
    stub_const("Debts::TransactionBackfiller::MAX_LINKS", 1)
    transaction_on(Date.new(2026, 1, 16))
    transaction_on(Date.new(2026, 1, 17))
    debt.update!(auto_sync_transactions: true)

    result = described_class.call(debt)

    expect(result.payload).to eq(linked: 0, skipped: true)
    expect(DebtTransaction.count).to eq(0)
  end

  it "does nothing when auto_sync is off" do
    transaction_on(Date.new(2026, 1, 16))

    result = described_class.call(debt)

    expect(result.payload).to eq(linked: 0, skipped: false)
    expect(DebtTransaction.count).to eq(0)
  end
end
