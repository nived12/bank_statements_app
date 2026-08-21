require "rails_helper"

RSpec.describe DebtTransaction, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:debt) { create(:debt, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15)) }

  def transaction_on(date)
    create(:transaction, user: user, bank_account: bank_account, category: category, date: date, amount: 500)
  end

  describe "validations" do
    it "rejects a transaction dated on opening_balance_date" do
      link = DebtTransaction.new(
        debt: debt, transaction_id: transaction_on(Date.new(2026, 1, 15)).id,
        amount_applied: 500
      )

      expect(link).not_to be_valid
      expect(link.errors[:transaction_id]).to be_present
    end

    it "accepts a transaction dated after opening_balance_date" do
      link = DebtTransaction.new(
        debt: debt, transaction_id: transaction_on(Date.new(2026, 1, 16)).id,
        amount_applied: 500
      )

      expect(link).to be_valid
    end
  end

  describe "recalculating the debt on unlink" do
    it "recalculates current_balance when the link is destroyed" do
      link = DebtTransaction.create!(
        debt: debt, transaction_id: transaction_on(Date.new(2026, 1, 16)).id,
        amount_applied: 500
      )
      expect(debt.reload.current_balance).to eq(500)

      link.destroy!

      expect(debt.reload.current_balance).to eq(1_000)
    end
  end
end
