class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :bank_account, null: false, foreign_key: true
      t.references :statement_file, null: false, foreign_key: true
      t.date    :date,        null: false
      t.string  :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false

      t.string  :transaction_type, null: false # "income", "fixed_expense", "variable_expense"
      t.string  :bank_entry_type # "credit"/"debit", optional

      t.string  :merchant
      t.string  :reference
      t.string  :category
      t.string  :sub_category

      t.timestamps
    end

    add_index :transactions, :date
    add_index :transactions, :transaction_type
    add_index :transactions, :category
  end
end
