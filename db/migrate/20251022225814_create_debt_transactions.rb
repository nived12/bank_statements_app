class CreateDebtTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :debt_transactions do |t|
      t.references :debt, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true
      t.decimal :amount_applied, precision: 12, scale: 2, null: false
      t.text :notes
      t.boolean :manual, default: true, null: false

      t.timestamps
    end

    add_index :debt_transactions, [:debt_id, :transaction_id], unique: true
  end
end
