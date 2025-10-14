class AddLinkedTransferToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :linked_transfer_id, :bigint
    add_index :transactions, :linked_transfer_id
    add_foreign_key :transactions, :transactions, column: :linked_transfer_id
  end
end
