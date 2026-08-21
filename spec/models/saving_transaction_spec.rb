require "rails_helper"

RSpec.describe SavingTransaction, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:saving) { create(:saving, user: user, opening_balance: 0, opening_balance_date: Date.new(2026, 1, 15)) }

  def transaction_on(date)
    create(:transaction, user: user, bank_account: bank_account, category: category, date: date, amount: 500)
  end

  describe "validations" do
    it "rejects a transaction dated on opening_balance_date" do
      link = SavingTransaction.new(
        saving: saving, transaction_id: transaction_on(Date.new(2026, 1, 15)).id,
        amount_applied: 500
      )

      expect(link).not_to be_valid
      expect(link.errors[:transaction_id]).to be_present
    end

    it "rejects a transaction dated before opening_balance_date" do
      link = SavingTransaction.new(
        saving: saving, transaction_id: transaction_on(Date.new(2026, 1, 10)).id,
        amount_applied: 500
      )

      expect(link).not_to be_valid
    end

    it "accepts a transaction dated after opening_balance_date" do
      link = SavingTransaction.new(
        saving: saving, transaction_id: transaction_on(Date.new(2026, 1, 16)).id,
        amount_applied: 500
      )

      expect(link).to be_valid
    end

    it "does not re-validate the date on update (on: :create only)" do
      link = SavingTransaction.create!(
        saving: saving, transaction_id: transaction_on(Date.new(2026, 1, 16)).id,
        amount_applied: 500
      )

      expect(link.update(notes: "edited")).to be true
    end
  end

  describe "recalculating the saving on unlink" do
    it "recalculates current_amount when the link is destroyed" do
      link = SavingTransaction.create!(
        saving: saving, transaction_id: transaction_on(Date.new(2026, 1, 16)).id,
        amount_applied: 500
      )
      expect(saving.reload.current_amount).to eq(500)

      link.destroy!

      expect(saving.reload.current_amount).to eq(0)
    end
  end
end
