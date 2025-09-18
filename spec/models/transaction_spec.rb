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

    it "requires bank_account but allows optional statement_file" do
      tx = Transaction.new(valid_params.merge(bank_account: nil))
      expect(tx).not_to be_valid

      tx = Transaction.new(valid_params.merge(statement_file: nil))
      expect(tx).to be_valid
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
      expect(Transaction.btype_debit).to include(fixed_tx)
      expect(Transaction.btype_debit).to include(variable_tx)
    end
  end

  describe "date range scopes" do
    let!(:old_tx) { create(:transaction, date: Date.new(2024, 1, 15)) }
    let!(:mid_tx) { create(:transaction, date: Date.new(2024, 6, 15)) }
    let!(:new_tx) { create(:transaction, date: Date.new(2024, 12, 15)) }

    it "filters by from_date" do
      result = Transaction.date_from(Date.new(2024, 6, 1))
      expect(result).to include(mid_tx, new_tx)
      expect(result).not_to include(old_tx)
    end

    it "filters by to_date" do
      result = Transaction.date_to(Date.new(2024, 6, 30))
      expect(result).to include(old_tx, mid_tx)
      expect(result).not_to include(new_tx)
    end

    it "filters by date range" do
      result = Transaction.date_range(Date.new(2024, 6, 1), Date.new(2024, 6, 30))
      expect(result).to include(mid_tx)
      expect(result).not_to include(old_tx, new_tx)
    end

    it "handles single date filters in date_range" do
      result = Transaction.date_range(Date.new(2024, 6, 1), nil)
      expect(result).to include(mid_tx, new_tx)
      expect(result).not_to include(old_tx)

      result = Transaction.date_range(nil, Date.new(2024, 6, 30))
      expect(result).to include(old_tx, mid_tx)
      expect(result).not_to include(new_tx)
    end

    it "returns all when no dates provided to date_range" do
      result = Transaction.date_range(nil, nil)
      expect(result).to include(old_tx, mid_tx, new_tx)
    end
  end

  describe "transaction relevance scopes and methods" do
    let(:opening_balance_date) { Date.new(2025, 1, 15) }
    let(:bank_account_with_opening_date) { create(:bank_account, user: user, opening_balance_date: opening_balance_date) }
    let(:statement_file_with_opening_date) { create(:statement_file, user: user, bank_account: bank_account_with_opening_date) }

    let!(:relevant_transaction) do
      create(:transaction,
        user: user,
        bank_account: bank_account_with_opening_date,
        statement_file: statement_file_with_opening_date,
        date: opening_balance_date + 5.days
      )
    end

    let!(:historical_transaction) do
      create(:transaction,
        user: user,
        bank_account: bank_account_with_opening_date,
        statement_file: statement_file_with_opening_date,
        date: opening_balance_date - 5.days
      )
    end

    describe "scopes" do
      it "filters relevant transactions for balance calculations" do
        relevant_transactions = Transaction.relevant_for_balance(opening_balance_date)
        expect(relevant_transactions).to include(relevant_transaction)
        expect(relevant_transactions).not_to include(historical_transaction)
      end

      it "filters historical transactions" do
        historical_transactions = Transaction.historical(opening_balance_date)
        expect(historical_transactions).to include(historical_transaction)
        expect(historical_transactions).not_to include(relevant_transaction)
      end

      it "handles edge case of exact opening balance date" do
        edge_case_transaction = create(:transaction,
          user: user,
          bank_account: bank_account_with_opening_date,
          statement_file: statement_file_with_opening_date,
          date: opening_balance_date
        )

        relevant_transactions = Transaction.relevant_for_balance(opening_balance_date)
        expect(relevant_transactions).to include(edge_case_transaction)

        historical_transactions = Transaction.historical(opening_balance_date)
        expect(historical_transactions).not_to include(edge_case_transaction)
      end
    end

    describe "instance methods" do
      it "correctly identifies relevant transactions" do
        expect(relevant_transaction.relevant_for_balance?).to be true
        expect(relevant_transaction.historical?).to be false
      end

      it "correctly identifies historical transactions" do
        expect(historical_transaction.relevant_for_balance?).to be false
        expect(historical_transaction.historical?).to be true
      end

      it "returns opening balance date from associated account" do
        expect(relevant_transaction.account_opening_balance_date).to eq(opening_balance_date)
      end

      it "handles nil bank account gracefully" do
        transaction_without_account = Transaction.new(valid_params.merge(bank_account: nil))
        expect(transaction_without_account.account_opening_balance_date).to be_nil
      end

      it "handles bank account with current date as opening balance date" do
        bank_account_with_current_date = create(:bank_account, user: user, opening_balance_date: Date.current)
        transaction_with_current_date = create(:transaction,
          user: user,
          bank_account: bank_account_with_current_date,
          statement_file: statement_file,
          date: Date.current
        )

        # Should be relevant when transaction date equals opening balance date
        expect(transaction_with_current_date.relevant_for_balance?).to be true
        expect(transaction_with_current_date.historical?).to be false
      end
    end
  end
end
