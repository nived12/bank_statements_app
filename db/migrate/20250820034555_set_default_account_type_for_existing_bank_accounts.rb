class SetDefaultAccountTypeForExistingBankAccounts < ActiveRecord::Migration[8.0]
  def up
    # Set all existing bank accounts to debit (0) as default
    execute "UPDATE bank_accounts SET account_type = 0 WHERE account_type IS NULL"
  end

  def down
    # This migration cannot be safely reversed
    # The account_type field will remain with its current values
  end
end
