class AddIndexToTransactionsDate < ActiveRecord::Migration[8.0]
  def change
    # Add composite index for better performance on balance calculations
    # This optimizes queries that filter by bank_account_id and date (opening_balance_date filtering)
    add_index :transactions, [ :bank_account_id, :date ], name: 'index_transactions_on_bank_account_id_and_date'
  end
end
