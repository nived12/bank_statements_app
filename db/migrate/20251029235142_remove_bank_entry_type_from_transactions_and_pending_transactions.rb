class RemoveBankEntryTypeFromTransactionsAndPendingTransactions < ActiveRecord::Migration[8.0]
  def change
    remove_column :transactions, :bank_entry_type, :string
    remove_column :pending_transactions, :bank_entry_type, :string
  end
end
