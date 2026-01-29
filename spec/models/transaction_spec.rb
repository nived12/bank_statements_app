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
      merchant: "Amazon",
      reference: "REF-123"
    }
  end

  describe "enums" do
    it "defines string-backed enum for transaction_type" do
      expect(Transaction.transaction_types.keys).to contain_exactly(
        "income", "fixed_expense", "variable_expense", "transfer_out", "transfer_in"
      )
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

    it "scopes by transaction_type" do
      expect(Transaction.ttype_income).to include(income_tx)
      expect(Transaction.ttype_fixed_expense).to include(fixed_tx)
      expect(Transaction.ttype_variable_expense).to include(variable_tx)
    end
  end

  describe "date range scopes" do
    let!(:old_tx) { create(:transaction, date: Date.new(2024, 1, 15)) }
    let!(:mid_tx) { create(:transaction, date: Date.new(2024, 6, 15)) }
    let!(:new_tx) { create(:transaction, date: Date.new(2024, 12, 15)) }

    it "filters transactions by date ranges correctly" do
      # Test from_date filter
      result = Transaction.date_from(Date.new(2024, 6, 1))
      expect(result).to include(mid_tx, new_tx)
      expect(result).not_to include(old_tx)

      # Test to_date filter
      result = Transaction.date_to(Date.new(2024, 6, 30))
      expect(result).to include(old_tx, mid_tx)
      expect(result).not_to include(new_tx)

      # Test date_range with both dates
      result = Transaction.date_range(Date.new(2024, 6, 1), Date.new(2024, 6, 30))
      expect(result).to include(mid_tx)
      expect(result).not_to include(old_tx, new_tx)

      # Test date_range with single dates
      result = Transaction.date_range(Date.new(2024, 6, 1), nil)
      expect(result).to include(mid_tx, new_tx)
      expect(result).not_to include(old_tx)

      result = Transaction.date_range(nil, Date.new(2024, 6, 30))
      expect(result).to include(old_tx, mid_tx)
      expect(result).not_to include(new_tx)

      # Test date_range with no dates (returns all)
      result = Transaction.date_range(nil, nil)
      expect(result).to include(old_tx, mid_tx, new_tx)
    end
  end

  describe "transaction relevance scopes and methods" do
    let(:opening_balance_date) { Date.new(2025, 1, 15) }
    let(:bank_account_with_opening_date) do
      create(:bank_account, user: user, opening_balance_date: opening_balance_date)
    end
    let(:statement_file_with_opening_date) do
      create(:statement_file, user: user, bank_account: bank_account_with_opening_date)
    end

    let!(:relevant_transaction) do
      create(
        :transaction,
        user: user,
        bank_account: bank_account_with_opening_date,
        statement_file: statement_file_with_opening_date,
        date: opening_balance_date + 5.days
      )
    end

    let!(:historical_transaction) do
      create(
        :transaction,
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
        edge_case_transaction = create(
          :transaction,
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
        transaction_with_current_date = create(
          :transaction,
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

  describe "transfer cascade deletion" do
    let(:source_account) { create(:bank_account, user: user) }
    let(:destination_account) { create(:bank_account, user: user) }

    let!(:transfer_out) do
      t = Transaction.new(
        user: user,
        bank_account: source_account,
        date: Date.today,
        description: "Test Transfer",
        amount: -100,
        transaction_type: :transfer_out,
        source: :manual
      )
      t.save(validate: false)
      t
    end

    let!(:transfer_in) do
      t = Transaction.new(
        user: user,
        bank_account: destination_account,
        date: Date.today,
        description: "Test Transfer",
        amount: 100,
        transaction_type: :transfer_in,
        source: :manual
      )
      t.save(validate: false)
      t
    end

    before do
      # Link the transfers together
      transfer_out.update_column(:linked_transfer_id, transfer_in.id)
      transfer_in.update_column(:linked_transfer_id, transfer_out.id)
      transfer_out.reload
      transfer_in.reload
    end

    context "when deleting transfer_out" do
      it "also deletes the linked transfer_in" do
        transfer_out_id = transfer_out.id
        transfer_in_id = transfer_in.id

        transfer_out.destroy

        expect(Transaction.exists?(transfer_out_id)).to be false
        expect(Transaction.exists?(transfer_in_id)).to be false
      end
    end

    context "when deleting transfer_in" do
      it "also deletes the linked transfer_out" do
        transfer_out_id = transfer_out.id
        transfer_in_id = transfer_in.id

        transfer_in.destroy

        expect(Transaction.exists?(transfer_in_id)).to be false
        expect(Transaction.exists?(transfer_out_id)).to be false
      end
    end

    context "when deleting a non-transfer transaction" do
      let(:regular_transaction) { create(:transaction, :variable_expense, user: user, bank_account: bank_account) }

      it "does not trigger cascade deletion" do
        regular_transaction_id = regular_transaction.id

        regular_transaction.destroy

        expect(Transaction.exists?(regular_transaction_id)).to be false
        # Transfer pair should still exist
        expect(Transaction.exists?(transfer_out.id)).to be true
        expect(Transaction.exists?(transfer_in.id)).to be true
      end
    end
  end
end
