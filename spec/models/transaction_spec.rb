require "rails_helper"

RSpec.describe Transaction, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:category) { create(:category, user: user, name: "Shopping") }

  let(:valid_params) do
    {
      user: user,
      bank_account: bank_account,
      statement_file: statement_file,
      category: category,
      date: Date.new(2025, 1, 5),
      description: "Test purchase",
      amount: -1299.99,
      transaction_type: "variable_expense",
      bank_entry_type: "debit",
      merchant: "Amazon",
      reference: "REF-123"
    }
  end

  describe "enums" do
    it "defines string-backed enum for transaction_type" do
      expect(Transaction.transaction_types.keys).to contain_exactly(
        "income", "fixed_expense", "variable_expense"
      )
    end

    it "defines string-backed enum for bank_entry_type" do
      expect(Transaction.bank_entry_types.keys).to contain_exactly("credit", "debit")
    end
  end

  describe "validations" do
    it "is valid with all required fields" do
      tx = Transaction.new(valid_params)
      expect(tx).to be_valid
    end

    it "requires bank_account and statement_file" do
      tx = Transaction.new(valid_params.merge(bank_account: nil))
      expect(tx).not_to be_valid

      tx = Transaction.new(valid_params.merge(statement_file: nil))
      expect(tx).not_to be_valid
    end

    it "requires date, description, amount, and transaction_type" do
      tx = Transaction.new(valid_params.merge(date: nil))
      expect(tx).not_to be_valid

      tx = Transaction.new(valid_params.merge(description: ""))
      expect(tx).not_to be_valid

      tx = Transaction.new(valid_params.merge(amount: nil))
      expect(tx).not_to be_valid

      tx = Transaction.new(valid_params.merge(transaction_type: nil))
      expect(tx).not_to be_valid
    end

    it "rejects invalid transaction_type values" do
      expect {
        Transaction.new(valid_params.merge(transaction_type: "weird"))
      }.to raise_error(ArgumentError, "'weird' is not a valid transaction_type")
    end

    it "allows nil bank_entry_type but rejects invalid values" do
      expect(Transaction.new(valid_params.merge(bank_entry_type: nil))).to be_valid
      expect {
        Transaction.new(valid_params.merge(bank_entry_type: "weird"))
      }.to raise_error(ArgumentError, "'weird' is not a valid bank_entry_type")
    end
  end

  describe "enum helpers and scopes" do
    let!(:income_tx) { create(:transaction, :income) }
    let!(:fixed_tx) { create(:transaction, :fixed_expense) }
    let!(:variable_tx) { create(:transaction, :variable_expense) }

    it "exposes transaction_type predicates" do
      expect(income_tx.ttype_income?).to be true
      expect(fixed_tx.ttype_fixed_expense?).to be true
      expect(variable_tx.ttype_variable_expense?).to be true
    end

    it "exposes bank_entry_type predicates" do
      expect(income_tx.btype_credit?).to be true
      expect(fixed_tx.btype_debit?).to be true
    end

    it "scopes by transaction_type" do
      expect(Transaction.ttype_income).to include(income_tx)
      expect(Transaction.ttype_fixed_expense).to include(fixed_tx)
      expect(Transaction.ttype_variable_expense).to include(variable_tx)
    end

    it "scopes by bank_entry_type" do
      expect(Transaction.btype_credit).to include(income_tx)
      expect(Transaction.btype_debit).to include(fixed_tx, variable_tx)
    end
  end
end
