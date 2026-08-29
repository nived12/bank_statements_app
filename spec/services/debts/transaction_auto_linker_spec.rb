require "rails_helper"

RSpec.describe Debts::TransactionAutoLinker do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let!(:debt) do
    create(
      :debt, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15),
      calculation_settings: { "expense" => "positive" }
    ).tap do |d|
      d.category_ids = [category.id]
      d.bank_account_ids = [bank_account.id]
      d.update!(auto_sync_transactions: true)
    end
  end

  # The service is only ever invoked via Transaction#after_commit, so creating a matching
  # transaction exercises the real wiring, not just the service in isolation.
  it "does not auto-link a transaction dated on or before opening_balance_date" do
    create(
      :transaction, :variable_expense, user: user, bank_account: bank_account, category: category,
      date: Date.new(2026, 1, 15)
    )

    expect(debt.reload.current_balance).to eq(1_000)
    expect(DebtTransaction.count).to eq(0)
  end

  it "auto-links a transaction dated after opening_balance_date" do
    transaction = create(
      :transaction, :variable_expense, user: user, bank_account: bank_account, category: category,
      date: Date.new(2026, 1, 16), amount: -300
    )

    expect(debt.reload.current_balance).to eq(700)
    expect(DebtTransaction.find_by(transaction_id: transaction.id)).to be_present
  end
end
