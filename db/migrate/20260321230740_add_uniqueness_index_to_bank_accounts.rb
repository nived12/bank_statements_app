class AddUniquenessIndexToBankAccounts < ActiveRecord::Migration[8.0]
  def change
    add_index :bank_accounts,
      [:user_id, :bank_id, :account_number],
      unique: true,
      where: "account_type != 'cash'",
      name: "index_bank_accounts_on_user_bank_account_number_unique"
  end
end
