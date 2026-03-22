class ChangeAccountTypeToStringInBankAccounts < ActiveRecord::Migration[8.0]
  def up
    add_column :bank_accounts, :account_type_string, :string, null: false, default: "debit"

    execute <<~SQL
      UPDATE bank_accounts SET account_type_string = CASE account_type
        WHEN 0 THEN 'debit'
        WHEN 1 THEN 'credit'
        WHEN 2 THEN 'cash'
        ELSE 'debit'
      END
    SQL

    remove_column :bank_accounts, :account_type
    rename_column :bank_accounts, :account_type_string, :account_type
    add_index :bank_accounts, :account_type, name: "index_bank_accounts_on_account_type"
  end

  def down
    add_column :bank_accounts, :account_type_int, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE bank_accounts SET account_type_int = CASE account_type
        WHEN 'debit'   THEN 0
        WHEN 'credit'  THEN 1
        WHEN 'cash'    THEN 2
        ELSE 0
      END
    SQL

    remove_column :bank_accounts, :account_type
    rename_column :bank_accounts, :account_type_int, :account_type
    add_index :bank_accounts, :account_type, name: "index_bank_accounts_on_account_type"
  end
end
