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
        "income", "fixed_expense", "variable_expense", "transfer_out", "transfer_in"
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

  describe "auto-linking to goals" do
    let!(:goal) do
      create(:goal,
             user: user,
             bank_account: bank_account,
             category: category,
             auto_link_category: true,
             goal_calculation_settings: {
               "income" => "positive",
               "expense" => "negative",
               "transfer_in" => "positive",
               "transfer_out" => "negative"
             })
    end

    context "when creating a transaction with matching criteria" do
      it "auto-links to matching goals" do
        expect { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }
          .to change { GoalTransaction.count }.by(1)

        goal_transaction = GoalTransaction.last
        expect(goal_transaction.goal).to eq(goal)
        expect(goal_transaction.notes).to eq("Auto-linked")
      end
    end

    context "when updating transaction category" do
      let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }
      let(:new_category) { create(:category, user: user) }

      it "re-evaluates goal linking" do
        # Transaction should be linked initially
        expect(transaction.goal_transactions.count).to eq(1)

        # Update category
        transaction.update!(category: new_category)

        # Should clear old links and not create new ones (no matching goal for new category)
        expect(transaction.goal_transactions.count).to eq(0)
      end
    end

    context "when updating transaction bank_account" do
      let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }
      let(:new_bank_account) { create(:bank_account, user: user) }

      it "re-evaluates goal linking" do
        # Transaction should be linked initially
        expect(transaction.goal_transactions.count).to eq(1)

        # Update bank_account
        transaction.update!(bank_account: new_bank_account)

        # Should clear old links and not create new ones (no matching goal for new bank account)
        expect(transaction.goal_transactions.count).to eq(0)
      end
    end

    context "when updating transaction date" do
      let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

      it "re-evaluates goal linking" do
        # Transaction should be linked initially
        expect(transaction.goal_transactions.count).to eq(1)

        # Update date to outside goal range
        transaction.update!(date: 1.year.from_now)

        # Should clear old links and not create new ones (date outside goal range)
        expect(transaction.goal_transactions.count).to eq(0)
      end
    end

    context "when transaction has no category" do
      it "does not auto-link" do
        expect { create(:transaction, user: user, bank_account: bank_account, category: nil, transaction_type: "income", amount: 100.0) }
          .not_to change { GoalTransaction.count }
      end
    end


    context "when updating non-relevant fields" do
      let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

      it "does not re-evaluate goal linking" do
        # Transaction should be linked initially
        expect(transaction.goal_transactions.count).to eq(1)

        # Update non-relevant field
        transaction.update!(description: "Updated description")

        # Should still be linked (no re-evaluation)
        expect(transaction.goal_transactions.count).to eq(1)
      end
    end
  end
end
