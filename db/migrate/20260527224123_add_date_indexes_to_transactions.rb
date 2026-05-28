class AddDateIndexesToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [:user_id, :date], name: "index_transactions_on_user_id_and_date"
    add_index :transactions, [:user_id, :bank_account_id, :date],
      name: "index_transactions_on_user_id_and_bank_account_id_and_date"
  end
end
