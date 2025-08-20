class AddAccountTypeToBankAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :bank_accounts, :account_type, :integer, null: false, default: 0
    add_index :bank_accounts, :account_type
  end
end
