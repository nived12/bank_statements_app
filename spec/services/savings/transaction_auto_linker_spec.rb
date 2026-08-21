require "rails_helper"

RSpec.describe Savings::TransactionAutoLinker do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let!(:saving) do
    create(
      :saving, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15),
      calculation_settings: { "income" => "positive" }
    ).tap do |s|
      s.category_ids = [category.id]
      s.bank_account_ids = [bank_account.id]
      s.update!(auto_sync_transactions: true)
    end
  end

  # The service is only ever invoked via Transaction#after_commit, so creating a matching
  # transaction exercises the real wiring, not just the service in isolation.
  it "does not auto-link a transaction dated on or before opening_balance_date" do
    create(
      :transaction, :income, user: user, bank_account: bank_account, category: category,
      date: Date.new(2026, 1, 15)
    )

    expect(saving.reload.current_amount).to eq(1_000)
    expect(SavingTransaction.count).to eq(0)
  end

  it "auto-links a transaction dated after opening_balance_date" do
    transaction = create(
      :transaction, :income, user: user, bank_account: bank_account, category: category,
      date: Date.new(2026, 1, 16), amount: 500
    )

    expect(saving.reload.current_amount).to eq(1_500)
    expect(SavingTransaction.find_by(transaction_id: transaction.id)).to be_present
  end
end
