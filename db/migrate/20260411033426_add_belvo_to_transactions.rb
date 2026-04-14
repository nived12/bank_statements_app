class AddBelvoToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :belvo_transaction_id, :string, null: true

    add_index :transactions, :belvo_transaction_id, unique: true, where: "belvo_transaction_id IS NOT NULL"
  end
end
