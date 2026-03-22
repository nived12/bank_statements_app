class DeduplicateBankAccounts < ActiveRecord::Migration[8.0]
  def up
    BankAccount.reset_column_information

    duplicates = BankAccount
      .where.not(account_type: "cash")
      .group(:user_id, :bank_id, :account_number)
      .having("COUNT(*) > 1")
      .pluck(:user_id, :bank_id, :account_number)

    duplicates.each do |user_id, bank_id, account_number|
      accounts = BankAccount.where(user_id: user_id, bank_id: bank_id, account_number: account_number)

      winner = accounts.max_by do |a|
        Transaction.where(bank_account_id: a.id).count +
          StatementFile.where(bank_account_id: a.id).count +
          PendingTransaction.where(bank_account_id: a.id).count +
          SavingBankAccount.where(bank_account_id: a.id).count +
          DebtBankAccount.where(bank_account_id: a.id).count
      end

      # Destroy losers with all their associated records (cascade).
      # We intentionally do NOT reassign records to the winner — if both accounts
      # had the same statements imported, reassigning would double-count transactions
      # and corrupt balances. The winner already holds the most complete data.
      accounts.where.not(id: winner.id).each(&:destroy)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
