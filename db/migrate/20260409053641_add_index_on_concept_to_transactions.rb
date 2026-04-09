class AddIndexOnConceptToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, :concept
    add_index :pending_transactions, :concept
  end
end
