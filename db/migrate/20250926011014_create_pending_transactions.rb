class CreatePendingTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :pending_transactions do |t|
      t.references :statement_file, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.date :date
      t.text :description
      t.decimal :amount
      t.string :transaction_type
      t.string :bank_entry_type
      t.string :merchant
      t.string :reference
      t.integer :category_id
      t.decimal :confidence
      t.decimal :category_confidence
      t.decimal :transaction_type_confidence
      t.integer :source, default: 0, null: false

      t.timestamps
    end

    add_index :pending_transactions, [ :user_id, :bank_account_id, :date, :amount ],
      name: 'index_pending_transactions_on_duplicate_fields'
    add_index :pending_transactions, :source
  end
end
