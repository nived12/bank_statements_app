class AddConfidenceFieldsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :confidence, :decimal, precision: 3, scale: 2, null: true
    add_column :transactions, :category_confidence, :decimal, precision: 3, scale: 2, null: true
    add_column :transactions, :transaction_type_confidence, :decimal, precision: 3, scale: 2, null: true
  end
end
