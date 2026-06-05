# frozen_string_literal: true

class CreateTransactionItemsAndAddTaxTip < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_items do |t|
      t.references :transaction, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :transaction_items, [:transaction_id, :position]

    add_column :transactions, :tax_amount, :decimal, precision: 12, scale: 2
    add_column :transactions, :tip_amount, :decimal, precision: 12, scale: 2
  end
end
