class SetDefaultOpeningBalanceDatesForExistingAccounts < ActiveRecord::Migration[8.0]
  def up
    # Set opening_balance_date to created_at for existing accounts
    # This ensures existing accounts have a valid opening balance date
    execute <<-SQL
      UPDATE bank_accounts#{" "}
      SET opening_balance_date = DATE(created_at)#{" "}
      WHERE opening_balance_date IS NULL
    SQL
  end

  def down
    # This migration cannot be safely reversed
    # Setting opening_balance_date to NULL would violate the NOT NULL constraint
    raise ActiveRecord::IrreversibleMigration,
      "Cannot reverse this migration due to NOT NULL constraint on opening_balance_date"
  end
end
